// Build gate: a deferred item tagged `owner: dev da <X>` must be dealt with by
// story X — not after it. Mirrors the style of tool/check_curriculum.dart and
// tool/check_module_boundaries.dart: read the files as text, print every
// violation, exit non-zero on any.
//
// WHY THIS IS A SCRIPT AND NOT A CHECKLIST ITEM
//
// Story 1.3 deferred two items with `owner: dev da 1.4`, in writing. Story 1.4
// was planned, implemented, reviewed and merged without touching either. One of
// them (concurrent `playSample`) was exactly the thing the first real consumer
// broke, and it took down `e2e-android` and three follow-up PRs. The other is
// still open. The Epic 1 retro had already produced the matching process item
// ("E2E generation is part of the story DoD, not a follow-up PR") and that one
// was skipped too.
//
// Two owner-tagged items, two misses; one process promise, one miss. A promise
// that has already failed is not a control. This turns it into a red build.
//
// The rule: for every story currently `in-progress` or `review` in
// sprint-status.yaml, no UNRESOLVED block in deferred-work.md may name it as
// `owner: dev da <that story>`. Either the story pulls the item into its spec
// and resolves it, or the item is re-triaged onto a different owner with the
// reason written down. Silently outliving the story is what stops being
// possible.
//
// A block counts as resolved when it says so — `RESOLVIDO` or a ✅ anywhere in
// the block. That is already the convention the file uses.
//
// Exit codes: 0 = OK, 1 = violations, 2 = a required file is missing.
//
// Usage: dart run tool/check_deferred_owners.dart [repo-root]

import 'dart:io';

import 'package:path/path.dart' as p;

const _sprintStatus =
    '_bmad-output/implementation-artifacts/sprint-status.yaml';
const _deferredWork = '_bmad-output/implementation-artifacts/deferred-work.md';

/// Story statuses that mean "this story is the one on the hook right now".
const _activeStatuses = {'in-progress', 'review'};

/// `1-4-exercício-de-...` -> `1.4`; `1-3b-produção-...` -> `1.3b`.
final _storyKey = RegExp(r'^(\d+)-(\d+[a-z]?)-');

/// `  1-4-…: review` — two-space indented mapping entries of development_status.
final _statusLine = RegExp(r'^ {2}([^\s:]+):\s*(\S+)\s*$');

/// `owner: dev da 1.4`, tolerating quotes, bold markers and the trailing
/// punctuation the file actually uses.
///
/// The leading lookbehind is load-bearing: a tag QUOTED in a code span —
/// ``owner: dev da 1.4`` in prose that *describes* a tag, including the triage
/// notes at the bottom of the file and this gate's own documentation — is not a
/// tag. Without it the gate flags its own explanation of itself, which is how
/// the first run went.
final _ownerTag = RegExp(
  r'(?<!`)owner:\s*["*]*\s*dev\s+da\s+([0-9]+\.[0-9]+[a-z]?)',
  caseSensitive: false,
);

void main(List<String> args) {
  final root = args.isNotEmpty ? args.first : Directory.current.path;

  final statusFile = File(p.join(root, _sprintStatus));
  final deferredFile = File(p.join(root, _deferredWork));
  for (final file in [statusFile, deferredFile]) {
    if (!file.existsSync()) {
      stderr.writeln('check_deferred_owners: not found at ${file.path}');
      exit(2);
    }
  }

  final active = _activeStories(statusFile.readAsLinesSync());
  if (active.isEmpty) {
    stdout.writeln(
      'check_deferred_owners: no story is in-progress/review — nothing to check',
    );
    return;
  }

  final problems = <String>[];
  for (final block in _blocks(deferredFile.readAsLinesSync())) {
    if (block.resolved) continue;
    for (final owner in block.owners) {
      if (!active.containsKey(owner)) continue;
      problems.add(
        '$_deferredWork:${block.line} — unresolved item owned by "dev da '
        '$owner", and story $owner is ${active[owner]}.\n'
        '    ${block.summary}',
      );
    }
  }

  if (problems.isEmpty) {
    stdout.writeln(
      'check_deferred_owners: OK — no unresolved item is owned by '
      '${active.keys.join(', ')}',
    );
    return;
  }

  stderr.writeln(
    'check_deferred_owners: ${problems.length} deferred item(s) tagged for a '
    'story that is currently active.\n'
    'Pull each into that story\'s spec and resolve it (mark the block '
    'RESOLVIDO), or re-triage it onto a different owner with the reason '
    'written down. Do not just delete the tag.\n',
  );
  for (final problem in problems) {
    stderr.writeln('  - $problem');
  }
  exit(1);
}

/// Story id -> status, for the stories that are `in-progress` or `review`.
Map<String, String> _activeStories(List<String> lines) {
  final active = <String, String>{};
  var inSection = false;
  for (final line in lines) {
    if (line.startsWith('development_status:')) {
      inSection = true;
      continue;
    }
    // Any other column-0 key ends the mapping (`action_items:`, …).
    if (inSection && line.isNotEmpty && !line.startsWith(' ')) break;
    if (!inSection) continue;

    final entry = _statusLine.firstMatch(line);
    if (entry == null) continue;
    if (!_activeStatuses.contains(entry.group(2))) continue;

    final story = _storyKey.firstMatch(entry.group(1)!);
    if (story == null) continue; // `epic-1`, `epic-1-retrospective`, …
    active['${story.group(1)}.${story.group(2)}'] = entry.group(2)!;
  }
  return active;
}

class _Block {
  _Block(this.line);

  final int line;
  final List<String> _lines = [];

  void add(String text) => _lines.add(text);

  bool get resolved =>
      _lines.any((l) => l.contains('RESOLVIDO') || l.contains('✅'));

  Set<String> get owners => {
    for (final l in _lines)
      for (final m in _ownerTag.allMatches(l)) m.group(1)!,
  };

  /// First non-empty line, trimmed for the error message.
  String get summary {
    final first = _lines.firstWhere(
      (l) => l.trim().isNotEmpty,
      orElse: () => '',
    );
    final text = first.trim();
    return text.length <= 110 ? text : '${text.substring(0, 107)}...';
  }
}

/// Splits the document into items. A new block starts at a heading or at a
/// column-0 list bullet; everything indented under a bullet belongs to it.
Iterable<_Block> _blocks(List<String> lines) sync* {
  _Block? current;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final startsBlock = line.startsWith('- ') || line.startsWith('#');
    if (startsBlock) {
      if (current != null) yield current;
      current = _Block(i + 1);
    }
    current?.add(line);
  }
  if (current != null) yield current;
}
