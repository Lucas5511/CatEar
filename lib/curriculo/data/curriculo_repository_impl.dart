/// Asset-backed [CurriculoRepository].
///
/// The implementation class is library-private: the only public symbol is
/// [curriculoRepositoryProvider], re-exported by the module barrel. The bundle
/// is injected via [catalogAssetBundleProvider] (the test seam).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show AssetBundle;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/catalogs.dart';
import '../domain/curriculo_repository.dart';
import '../domain/curriculum.dart';
import '../domain/curriculum_validation.dart';
import '../domain/enums.dart';
import 'catalog_asset_bundle.dart';

part 'curriculo_repository_impl.g.dart';

/// Provides the curriculum repository. Consumers depend only on this.
@riverpod
CurriculoRepository curriculoRepository(Ref ref) =>
    _AssetCurriculoRepository(ref.watch(catalogAssetBundleProvider));

/// Reads `catalog_v1.json` from an [AssetBundle], validates it with the shared
/// rules, and maps it onto pure domain models.
class _AssetCurriculoRepository implements CurriculoRepository {
  _AssetCurriculoRepository(this._bundle);

  final AssetBundle _bundle;

  @override
  Future<Curriculum> load() async {
    final String raw;
    try {
      raw = await _bundle.loadString(catalogAssetKey);
    } on FlutterError {
      // The bundle has no such asset (the canonical "missing asset" signal).
      throw const CurriculumError.assetNotFound(catalogAssetKey);
    } catch (e) {
      // Anything else (I/O error, a corrupted bundle) is not "missing" — do
      // not mask it as AssetNotFound.
      throw CurriculumError.malformedCatalog(
        '<root>',
        'could not read asset: $e',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw CurriculumError.malformedCatalog(
        '<root>',
        'unreadable JSON: ${e.message}',
      );
    }

    final violations = validateCatalogStructure(decoded);
    if (violations.isNotEmpty) {
      throw _asError(violations.first);
    }

    // Validation is exhaustive, but never let a raw TypeError/CastError from
    // the mapping step cross the boundary — the spec forbids it.
    try {
      return _map((decoded! as Map).cast<String, dynamic>());
    } on CurriculumError {
      rethrow;
    } catch (e) {
      throw CurriculumError.malformedCatalog('<root>', 'internal: $e');
    }
  }

  CurriculumError _asError(CurriculumViolation v) => switch (v.kind) {
    ViolationKind.unknownValue => CurriculumError.unknownValue(v.path, v.value),
    ViolationKind.malformed => CurriculumError.malformedCatalog(
      v.path,
      v.message,
    ),
  };

  Curriculum _map(Map<String, dynamic> json) {
    final catalogs = _Catalogs.fromJson(json);

    // Always hand consumers the stages in progression order — the JSON array
    // order is not canonical, `order` is.
    final stages = <Stage>[
      for (final raw in json['stages'] as List)
        _mapStage((raw as Map).cast<String, dynamic>(), catalogs),
    ]..sort((a, b) => a.order.compareTo(b.order));

    final errorTypes = <ErrorType>{
      for (final id in json['errorTypes'] as List)
        ErrorType.fromJson('errorTypes', id as String),
    };

    return Curriculum(
      schemaVersion: json['schemaVersion'] as int,
      stages: stages,
      errorTypes: errorTypes,
    );
  }

  Stage _mapStage(Map<String, dynamic> s, _Catalogs catalogs) {
    final ts = s['timbreScaffold'];
    return Stage(
      stageId: s['stageId'] as String,
      order: s['order'] as int,
      scaffoldIntensity: (s['scaffoldIntensity'] as num?)?.toDouble(),
      timbreScaffold: ts == null
          ? null
          : TimbreScaffold.fromJson('timbreScaffold', ts as String),
      exercises: <Exercise>[
        for (final raw in s['exercises'] as List)
          _mapExercise((raw as Map).cast<String, dynamic>(), catalogs),
      ],
    );
  }

  Exercise _mapExercise(Map<String, dynamic> e, _Catalogs catalogs) {
    final refs = (e['audioSampleRefs'] as List).cast<String>();
    final type = ExerciseType.fromJson(
      'exerciseType',
      e['exerciseType'] as String,
    );
    return switch (type) {
      ExerciseType.interval => IntervalExercise(
        interval: catalogs.intervals[e['interval']]!,
        direction: Direction.fromJson('direction', e['direction'] as String),
        audioSampleRefs: refs,
      ),
      ExerciseType.scale => ScaleExercise(
        scale: catalogs.scales[e['scaleType']]!,
        direction: Direction.fromJson('direction', e['direction'] as String),
        audioSampleRefs: refs,
      ),
      ExerciseType.chord => ChordExercise(
        chord: catalogs.chords[e['chordQuality']]!,
        audioSampleRefs: refs,
      ),
      ExerciseType.resolution => ResolutionExercise(
        cadence: catalogs.cadences[e['cadence']]!,
        audioSampleRefs: refs,
      ),
    };
  }
}

/// The four id-indexed `*Catalog`s, resolved once per [load].
class _Catalogs {
  _Catalogs({
    required this.intervals,
    required this.chords,
    required this.scales,
    required this.cadences,
  });

  factory _Catalogs.fromJson(Map<String, dynamic> json) {
    Map<String, T> index<T>(
      String key,
      T Function(Map<String, dynamic>) build,
    ) => {
      for (final raw in json[key] as List)
        (raw as Map)['id'] as String: build(raw.cast<String, dynamic>()),
    };

    return _Catalogs(
      intervals: index(
        'intervalCatalog',
        (m) => IntervalSpec(
          id: m['id'] as String,
          semitones: m['semitones'] as int,
          nameUi: m['nameUi'] as String,
          abbr: m['abbr'] as String,
          quality: m['quality'] as String,
        ),
      ),
      chords: index(
        'chordCatalog',
        (m) => ChordSpec(
          id: m['id'] as String,
          nameUi: m['nameUi'] as String,
          intervals: (m['intervals'] as List).cast<int>(),
          inversion: m['inversion'] as int,
        ),
      ),
      scales: index(
        'scaleCatalog',
        (m) => ScaleSpec(
          id: m['id'] as String,
          nameUi: m['nameUi'] as String,
          steps: (m['steps'] as List).cast<int>(),
        ),
      ),
      cadences: index(
        'cadenceCatalog',
        (m) => CadenceSpec(
          id: m['id'] as String,
          nameUi: m['nameUi'] as String,
          degrees: (m['degrees'] as List).cast<String>(),
        ),
      ),
    );
  }

  final Map<String, IntervalSpec> intervals;
  final Map<String, ChordSpec> chords;
  final Map<String, ScaleSpec> scales;
  final Map<String, CadenceSpec> cadences;
}
