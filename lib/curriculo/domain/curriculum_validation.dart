/// Shared validation for the curriculum catalog.
///
/// Single source of truth for the rules that both [CurriculoRepository.load]
/// (runtime) and `tool/check_curriculum.dart` (build gate) rely on. Operates on
/// the raw decoded `Map` and returns every violation it finds — the caller
/// decides what to do (throw the first as a `CurriculumError`, or print them
/// all and aggregate an exit code).
///
/// This file is **pure Dart** (no Flutter import) so the build-gate script can
/// `dart run` it.
///
/// Two entry points:
///  * [validateCatalogStructure] — everything `load()` validates (root shape,
///    `schemaVersion`, `stages` / `errorTypes` / `*Catalog` shape, every stage
///    and exercise). `load()` calls only this.
///  * [checkFadingAndOrder] — R1 (`order` unique + strictly increasing), R2
///    (colour scaffold only fades), R3 (`clean` timbre never after `vibrato`).
///    These are content invariants owned solely by the build gate; `load()`
///    never calls them.
library;

import 'curriculum_error.dart';
import 'enums.dart';

/// Why a value is rejected.
enum ViolationKind {
  /// Structural: wrong type, missing field, out-of-range, violated
  /// bicondicional, duplicated id, incomplete set, broken invariant.
  malformed,

  /// A token outside the frozen taxonomy, or an exercise id resolving against
  /// no `*Catalog` entry.
  unknownValue,
}

/// One rejected value, located by [path].
class CurriculumViolation {
  const CurriculumViolation(
    this.path,
    this.message, {
    this.kind = ViolationKind.malformed,
    this.value = '',
  });

  /// Field path or catalog entry, e.g. `schemaVersion`,
  /// `stages[s-tercas].exercises[0].direction`, `intervalCatalog[3].nameUi`.
  final String path;
  final String message;
  final ViolationKind kind;

  /// The offending value verbatim (for [ViolationKind.unknownValue]).
  final String value;

  @override
  String toString() => '$path: $message';
}

const _sampleRefPattern = r'^[a-z0-9_]+$';

/// Id field name carried by each exercise type, and the catalog it resolves
/// against.
const _idField = <ExerciseType, String>{
  ExerciseType.interval: 'interval',
  ExerciseType.chord: 'chordQuality',
  ExerciseType.scale: 'scaleType',
  ExerciseType.resolution: 'cadence',
};

const _catalogKeyFor = <ExerciseType, String>{
  ExerciseType.interval: 'intervalCatalog',
  ExerciseType.chord: 'chordCatalog',
  ExerciseType.scale: 'scaleCatalog',
  ExerciseType.resolution: 'cadenceCatalog',
};

// ---------------------------------------------------------------------------
// Structural validation (also enforced at runtime by load()).
// ---------------------------------------------------------------------------

/// Validates everything `load()` validates. Returns `[]` when the catalog is
/// structurally sound.
List<CurriculumViolation> validateCatalogStructure(Object? root) {
  final v = <CurriculumViolation>[];

  final json = _asObject(root, '<root>', v);
  if (json == null) return v;

  _validateSchemaVersion(json['schemaVersion'], v);

  final catalogIds = <String, Set<String>>{};
  for (final key in const [
    'intervalCatalog',
    'chordCatalog',
    'scaleCatalog',
    'cadenceCatalog',
  ]) {
    catalogIds[key] = _validateCatalog(key, json[key], v);
  }

  _validateErrorTypes(json['errorTypes'], v);
  _validateStages(json['stages'], catalogIds, v);

  return v;
}

Map<String, dynamic>? _asObject(
  Object? raw,
  String path,
  List<CurriculumViolation> v,
) {
  if (raw is Map) return raw.cast<String, dynamic>();
  v.add(CurriculumViolation(path, 'must be a JSON object'));
  return null;
}

void _validateSchemaVersion(Object? raw, List<CurriculumViolation> v) {
  if (raw == null) {
    v.add(const CurriculumViolation('schemaVersion', 'missing'));
    return;
  }
  if (raw is! int) {
    v.add(
      CurriculumViolation(
        'schemaVersion',
        'must be an int, got ${raw.runtimeType}',
      ),
    );
    return;
  }
  if (raw != 1) {
    v.add(CurriculumViolation('schemaVersion', 'must be 1 in v1, got $raw'));
  }
}

Set<String> _validateCatalog(
  String key,
  Object? raw,
  List<CurriculumViolation> v,
) {
  final ids = <String>{};
  if (raw == null) {
    v.add(CurriculumViolation(key, 'missing'));
    return ids;
  }
  if (raw is! List) {
    v.add(CurriculumViolation(key, 'must be a list, got ${raw.runtimeType}'));
    return ids;
  }
  for (var i = 0; i < raw.length; i++) {
    final entry = raw[i];
    final path = '$key[$i]';
    if (entry is! Map) {
      v.add(CurriculumViolation(path, 'must be an object'));
      continue;
    }
    final e = entry.cast<String, dynamic>();
    final id = e['id'];
    if (id is! String || id.isEmpty) {
      v.add(CurriculumViolation('$path.id', 'must be a non-empty string'));
    } else if (!ids.add(id)) {
      v.add(CurriculumViolation(path, 'duplicate id "$id" in $key'));
    }
    _requireString(e['nameUi'], '$path.nameUi', v);
    switch (key) {
      case 'intervalCatalog':
        _requireInt(e['semitones'], '$path.semitones', v);
        _requireString(e['abbr'], '$path.abbr', v);
        _requireString(e['quality'], '$path.quality', v);
      case 'chordCatalog':
        _requireIntList(e['intervals'], '$path.intervals', v);
        _requireInt(e['inversion'], '$path.inversion', v);
      case 'scaleCatalog':
        _requireIntList(e['steps'], '$path.steps', v);
      case 'cadenceCatalog':
        _requireStringList(e['degrees'], '$path.degrees', v);
    }
  }
  return ids;
}

void _validateErrorTypes(Object? raw, List<CurriculumViolation> v) {
  if (raw == null) {
    v.add(const CurriculumViolation('errorTypes', 'missing'));
    return;
  }
  if (raw is! List) {
    v.add(
      CurriculumViolation(
        'errorTypes',
        'must be a list, got ${raw.runtimeType}',
      ),
    );
    return;
  }
  if (raw.isEmpty) {
    v.add(const CurriculumViolation('errorTypes', 'must not be empty'));
    return;
  }
  final seen = <String>{};
  for (var i = 0; i < raw.length; i++) {
    final item = raw[i];
    if (item is! String) {
      v.add(CurriculumViolation('errorTypes[$i]', 'must be a string'));
      continue;
    }
    if (!seen.add(item)) {
      v.add(CurriculumViolation('errorTypes[$i]', 'duplicate "$item"'));
    }
    try {
      ErrorType.fromJson('errorTypes[$i]', item);
    } on CurriculumError {
      v.add(
        CurriculumViolation(
          'errorTypes[$i]',
          'unknown errorType "$item"',
          kind: ViolationKind.unknownValue,
          value: item,
        ),
      );
    }
  }
  final expected = ErrorType.values.map((e) => e.id).toSet();
  final missing = expected.difference(seen);
  if (missing.isNotEmpty) {
    final sorted = missing.toList()..sort();
    v.add(
      CurriculumViolation(
        'errorTypes',
        'must be exactly the ErrorType set; missing: ${sorted.join(', ')}',
      ),
    );
  }
}

void _validateStages(
  Object? raw,
  Map<String, Set<String>> catalogIds,
  List<CurriculumViolation> v,
) {
  if (raw == null) {
    v.add(const CurriculumViolation('stages', 'missing'));
    return;
  }
  if (raw is! List) {
    v.add(
      CurriculumViolation('stages', 'must be a list, got ${raw.runtimeType}'),
    );
    return;
  }
  if (raw.isEmpty) {
    v.add(const CurriculumViolation('stages', 'must not be empty'));
    return;
  }

  final seenStageIds = <String>{};
  for (var i = 0; i < raw.length; i++) {
    final entry = raw[i];
    if (entry is! Map) {
      v.add(CurriculumViolation('stages[$i]', 'must be an object'));
      continue;
    }
    final s = entry.cast<String, dynamic>();

    final rawId = s['stageId'];
    final label = (rawId is String && rawId.isNotEmpty) ? rawId : '#$i';
    final path = 'stages[$label]';
    if (rawId is! String || rawId.isEmpty) {
      v.add(CurriculumViolation('$path.stageId', 'must be a non-empty string'));
    } else if (!seenStageIds.add(rawId)) {
      v.add(CurriculumViolation(path, 'duplicate stageId "$rawId"'));
    }

    _requireInt(s['order'], '$path.order', v);

    final si = s['scaffoldIntensity'];
    if (si != null) {
      if (si is! num || si.isNaN) {
        v.add(
          CurriculumViolation(
            '$path.scaffoldIntensity',
            'must be a number 0.0–1.0',
          ),
        );
      } else if (si < 0.0 || si > 1.0) {
        v.add(
          CurriculumViolation(
            '$path.scaffoldIntensity',
            'must be within 0.0–1.0, got $si',
          ),
        );
      }
    }

    final ts = s['timbreScaffold'];
    if (ts != null) {
      if (ts is! String) {
        v.add(CurriculumViolation('$path.timbreScaffold', 'must be a string'));
      } else {
        try {
          TimbreScaffold.fromJson('$path.timbreScaffold', ts);
        } on CurriculumError {
          v.add(
            CurriculumViolation(
              '$path.timbreScaffold',
              'unknown timbreScaffold "$ts"',
              kind: ViolationKind.unknownValue,
              value: ts,
            ),
          );
        }
      }
    }

    _validateExercises(s['exercises'], path, catalogIds, v);
  }
}

void _validateExercises(
  Object? raw,
  String stagePath,
  Map<String, Set<String>> catalogIds,
  List<CurriculumViolation> v,
) {
  if (raw == null) {
    v.add(CurriculumViolation('$stagePath.exercises', 'missing'));
    return;
  }
  if (raw is! List) {
    v.add(CurriculumViolation('$stagePath.exercises', 'must be a list'));
    return;
  }
  if (raw.isEmpty) {
    v.add(CurriculumViolation('$stagePath.exercises', 'must not be empty'));
    return;
  }

  for (var j = 0; j < raw.length; j++) {
    final entry = raw[j];
    final path = '$stagePath.exercises[$j]';
    if (entry is! Map) {
      v.add(CurriculumViolation(path, 'must be an object'));
      continue;
    }
    final e = entry.cast<String, dynamic>();

    final rawType = e['exerciseType'];
    ExerciseType? type;
    if (rawType is! String) {
      v.add(CurriculumViolation('$path.exerciseType', 'must be a string'));
    } else {
      try {
        type = ExerciseType.fromJson('$path.exerciseType', rawType);
      } on CurriculumError {
        v.add(
          CurriculumViolation(
            '$path.exerciseType',
            'unknown exerciseType "$rawType"',
            kind: ViolationKind.unknownValue,
            value: rawType,
          ),
        );
      }
    }

    _validateSampleRefs(e['audioSampleRefs'], '$path.audioSampleRefs', v);

    if (type == null) continue;

    _validateDirection(e['direction'], type, '$path.direction', v);
    _validateRequiresVoice(e['requiresVoice'], type, '$path.requiresVoice', v);
    _validateExerciseId(e, type, path, catalogIds, v);
  }
}

void _validateDirection(
  Object? rawDir,
  ExerciseType type,
  String path,
  List<CurriculumViolation> v,
) {
  final needsDirection =
      type == ExerciseType.interval || type == ExerciseType.scale;
  if (!needsDirection) {
    if (rawDir != null) {
      v.add(CurriculumViolation(path, 'forbidden on $type exercises'));
    }
    return;
  }
  if (rawDir == null) {
    v.add(CurriculumViolation(path, 'required for $type exercises'));
    return;
  }
  if (rawDir is! String) {
    v.add(CurriculumViolation(path, 'must be a string'));
    return;
  }
  try {
    Direction.fromJson(path, rawDir);
  } on CurriculumError {
    v.add(
      CurriculumViolation(
        path,
        'unknown direction "$rawDir"',
        kind: ViolationKind.unknownValue,
        value: rawDir,
      ),
    );
  }
}

void _validateRequiresVoice(
  Object? rawVoice,
  ExerciseType type,
  String path,
  List<CurriculumViolation> v,
) {
  if (type == ExerciseType.resolution) {
    if (rawVoice != true) {
      v.add(
        CurriculumViolation(
          path,
          'must be present and true on resolution exercises',
        ),
      );
    }
  } else if (rawVoice != null) {
    v.add(CurriculumViolation(path, 'must be omitted on $type exercises'));
  }
}

void _validateExerciseId(
  Map<String, dynamic> e,
  ExerciseType type,
  String path,
  Map<String, Set<String>> catalogIds,
  List<CurriculumViolation> v,
) {
  final field = _idField[type]!;
  final catalogKey = _catalogKeyFor[type]!;
  final rawRefId = e[field];
  if (rawRefId is! String || rawRefId.isEmpty) {
    v.add(CurriculumViolation('$path.$field', 'must be a non-empty string'));
    return;
  }
  if (!(catalogIds[catalogKey] ?? const <String>{}).contains(rawRefId)) {
    v.add(
      CurriculumViolation(
        '$path.$field',
        'id "$rawRefId" has no entry in $catalogKey',
        kind: ViolationKind.unknownValue,
        value: rawRefId,
      ),
    );
  }
}

void _validateSampleRefs(
  Object? raw,
  String path,
  List<CurriculumViolation> v,
) {
  if (raw == null) {
    v.add(CurriculumViolation(path, 'missing'));
    return;
  }
  if (raw is! List) {
    v.add(CurriculumViolation(path, 'must be a list of tokens'));
    return;
  }
  if (raw.isEmpty) {
    v.add(CurriculumViolation(path, 'must not be empty'));
    return;
  }
  final re = RegExp(_sampleRefPattern);
  for (var i = 0; i < raw.length; i++) {
    final token = raw[i];
    if (token is! String || !re.hasMatch(token)) {
      v.add(
        CurriculumViolation(
          '$path[$i]',
          'token must match /$_sampleRefPattern/, got "$token"',
        ),
      );
    }
  }
}

void _requireString(Object? raw, String path, List<CurriculumViolation> v) {
  if (raw is! String || raw.isEmpty) {
    v.add(CurriculumViolation(path, 'must be a non-empty string'));
  }
}

void _requireInt(Object? raw, String path, List<CurriculumViolation> v) {
  if (raw == null) {
    v.add(CurriculumViolation(path, 'missing'));
  } else if (raw is! int) {
    v.add(CurriculumViolation(path, 'must be an int, got ${raw.runtimeType}'));
  }
}

void _requireIntList(Object? raw, String path, List<CurriculumViolation> v) {
  if (raw is! List || raw.isEmpty || raw.any((x) => x is! int)) {
    v.add(CurriculumViolation(path, 'must be a non-empty list of ints'));
  }
}

void _requireStringList(Object? raw, String path, List<CurriculumViolation> v) {
  if (raw is! List || raw.isEmpty || raw.any((x) => x is! String)) {
    v.add(CurriculumViolation(path, 'must be a non-empty list of strings'));
  }
}

// ---------------------------------------------------------------------------
// Content invariants — build gate only (R1 / R2 / R3).
// ---------------------------------------------------------------------------

/// One stage reduced to the fields R1–R3 care about.
class _StageView {
  _StageView(this.label, this.order, this.scaffold, this.timbre);

  final String label;
  final int order;
  final double? scaffold;
  final String? timbre;
}

/// R1: `order` is unique and strictly increasing once stages are sorted by
/// `order` (so the `stages` array may be authored in any sequence — gaps like
/// `[1, 3, 5]` are allowed, only duplicates fail).
/// R2: on the subsequence of stages that HAVE `scaffoldIntensity`, ordered by
/// `order`, each value is `<=` the previous one.
/// R3: `timbreScaffold` "cleanliness" only decreases — `clean` never follows
/// `vibrato` in `order`.
///
/// Defensive: stages without a usable `stageId` / `order` are skipped (the
/// structural pass already reported them).
List<CurriculumViolation> checkFadingAndOrder(Object? root) {
  final out = <CurriculumViolation>[];
  if (root is! Map) return out;
  final rawStages = root['stages'];
  if (rawStages is! List) return out;

  final views = <_StageView>[];
  for (var i = 0; i < rawStages.length; i++) {
    final s = rawStages[i];
    if (s is! Map) continue;
    final order = s['order'];
    if (order is! int) continue;
    final id = s['stageId'];
    final label = (id is String && id.isNotEmpty) ? id : '#$i';
    final si = s['scaffoldIntensity'];
    final ts = s['timbreScaffold'];
    views.add(
      _StageView(
        label,
        order,
        (si is num && !si.isNaN) ? si.toDouble() : null,
        ts is String ? ts : null,
      ),
    );
  }

  views.sort((a, b) => a.order.compareTo(b.order));

  // R1 — unique + strictly increasing (post-sort, that means: no duplicates).
  for (var i = 1; i < views.length; i++) {
    final prev = views[i - 1];
    final cur = views[i];
    if (cur.order <= prev.order) {
      out.add(
        CurriculumViolation(
          'stages[${cur.label}]',
          'R1 — order ${cur.order} is not greater than the previous stage '
              '"${prev.label}" (order ${prev.order}); order must be unique and '
              'strictly increasing',
        ),
      );
    }
  }

  // R2 — colour scaffold only fades.
  _StageView? lastScaffold;
  for (final v in views) {
    if (v.scaffold == null) continue;
    if (lastScaffold != null && v.scaffold! > lastScaffold.scaffold!) {
      out.add(
        CurriculumViolation(
          'stages[${v.label}]',
          'R2 — scaffoldIntensity ${v.scaffold} rises above the previous '
              'scaffolded stage "${lastScaffold.label}" '
              '(${lastScaffold.scaffold})',
        ),
      );
    }
    lastScaffold = v;
  }

  // R3 — `clean` never after `vibrato`.
  _StageView? firstVibrato;
  for (final v in views) {
    if (v.timbre == null) continue;
    if (v.timbre == 'vibrato') {
      firstVibrato ??= v;
    } else if (v.timbre == 'clean' && firstVibrato != null) {
      out.add(
        CurriculumViolation(
          'stages[${v.label}]',
          'R3 — timbreScaffold "clean" follows "vibrato" '
              '("${firstVibrato.label}") in order',
        ),
      );
    }
  }

  return out;
}
