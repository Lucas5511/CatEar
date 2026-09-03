#!/usr/bin/env bash
# Runs every CI gate. Steps are independent: each runs even if an earlier one
# failed, and the aggregate exit code is non-zero if any step failed.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0
step() {
  local name="$1"; shift
  echo ""
  echo "=== $name ==="
  if "$@"; then
    echo "--- $name: OK"
  else
    echo "--- $name: FAILED"
    fail=1
  fi
}

step "pub get"            flutter pub get
step "build_runner"       dart run build_runner build --delete-conflicting-outputs
step "schema dump"        dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/
step "contrast audit"     dart run tool/gen_contrast_audit.dart
step "format"             dart format --output=none --set-exit-if-changed .
step "analyze"            flutter analyze
step "module boundaries"  dart run tool/check_module_boundaries.dart
step "app id"             dart run tool/check_app_id.dart
step "curriculum"         dart run tool/check_curriculum.dart
step "deferred owners"    dart run tool/check_deferred_owners.dart
step "test"               flutter test

echo ""
if [ "$fail" -ne 0 ]; then
  echo "CI: FAILED"
  exit 1
fi
echo "CI: OK"
