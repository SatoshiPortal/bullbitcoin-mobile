#!/usr/bin/env bash
# Runs the unit tests of the current workspace member, or one shard of them.
#
# Usage: unit_test_shard.sh flutter|dart [test args...]
#
# With TEST_TOTAL_SHARDS > 1, the member's test files are dealt round-robin across the shards and TEST_SHARD_INDEX picks one.
# Sharding by file compiles each file once in total, whereas the runners' own --total-shards splits tests and so loads and compiles every file in every shard.
# The deal starts at an offset derived from the member name so that small members do not all land on shard 0.
set -euo pipefail

runner=$1
shift
total=${TEST_TOTAL_SHARDS:-1}
index=${TEST_SHARD_INDEX:-0}

# Match the PATH used by prepare-x64 before the outer FVM/Melos invocation.
if [[ ${MELOS_PACKAGE_NAME:-} == access && -n ${ACCESS_UNIT_TEST_PATH:-} ]]; then
  export PATH="$ACCESS_UNIT_TEST_PATH"
fi

if [[ "$total" -le 1 ]]; then
  exec fvm "$runner" test "$@"
fi
if [[ "$index" -lt 0 || "$index" -ge "$total" ]]; then
  echo "TEST_SHARD_INDEX must be in [0, $total), got $index" >&2
  exit 2
fi

offset=$(( $(printf %s "${MELOS_PACKAGE_NAME:-$(basename "$PWD")}" | cksum | cut -d' ' -f1) % total ))
mapfile -t files < <(
  find test -name '*_test.dart' -type f | LC_ALL=C sort |
    awk -v n="$total" -v i="$index" -v o="$offset" '(NR - 1 + o) % n == i'
)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No test files in shard $index of $total."
  exit 0
fi
echo "Shard $index of $total: ${#files[@]} test files."
if [[ ${TRACE_ACCESS_SHARD:-0} == 1 && $runner == flutter && ${MELOS_PACKAGE_NAME:-} == access && $total == 3 && $index == 1 ]]; then
  # Keep the original invocation and opt in to filtered verbose diagnostics in CI.
  # Emit only fixed labels and numeric values, never environment or arguments.
  start=$SECONDS
  echo "Access shard trace: start"
  status=0
  if [[ ${TRACE_ACCESS_HOOKS:-0} == 1 ]]; then
    python3 "$(dirname "${BASH_SOURCE[0]}")/trace_access_hooks.py" \
      fvm "$runner" test "$@" -v "${files[@]}" || status=$?
  else
    fvm "$runner" test "$@" "${files[@]}" || status=$?
  fi
  echo "Access shard trace: end (elapsed $((SECONDS - start))s, exit $status)"
  exit "$status"
fi
exec fvm "$runner" test "$@" "${files[@]}"
