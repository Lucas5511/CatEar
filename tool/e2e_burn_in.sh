#!/usr/bin/env bash
# Runs `flutter test integration_test` ITERATIONS times in a row against the
# device/emulator that is already up, and prints a tally. Exit 0 only if every
# iteration passed.
#
# WHY THIS IS A FILE AND NOT INLINE IN THE WORKFLOW
#
# `reactivecircus/android-emulator-runner` executes its `script` input line by
# line, each line in its own `sh -c`. A multi-line `case`/`for` never survives
# that: the first line alone is a syntax error, so from PR #17 until 2026-09-15
# the nightly burn-in died in ~3.5 min before running a single test, eight
# nights in a row, and the flake rate the Epic 1 retro asked for never existed.
# The workflow now calls this file on one line.
#
# Usage: ITERATIONS=5 bash tool/e2e_burn_in.sh
#        bash tool/e2e_burn_in.sh 3
set -u

iterations="${1:-${ITERATIONS:-5}}"
case "$iterations" in
  ''|*[!0-9]*|0)
    echo "iterations must be a positive integer, got: '$iterations'" >&2
    exit 2
    ;;
esac

pass=0
fail=0
for i in $(seq 1 "$iterations"); do
  echo "::group::burn-in iteration $i/$iterations"
  if flutter test integration_test; then
    pass=$((pass + 1))
    echo "iteration $i: PASS"
  else
    fail=$((fail + 1))
    echo "iteration $i: FAIL"
  fi
  echo "::endgroup::"
done

echo "burn-in tally: $pass passed, $fail failed, out of $iterations"
[ "$fail" -eq 0 ]
