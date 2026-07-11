#!/usr/bin/env bash
# audit-sp-invariant.sh: Static analysis enforcing SP no-autoscan invariants.
#
# Exit codes: 0 clean, 1 invariant violation, 2 tooling error (rg missing/broken).
#
# This is a grep-based gate, not a proof. It confines the known scan entry points
# to their allowed files; a scan wired through an untracked indirection can still
# slip past it, so human review of SP and sync lifecycle code stays required.
set -euo pipefail

command -v rg >/dev/null || { echo "rg not installed"; exit 2; }

# rg exit codes: 0 match, 1 no match, >=2 real error. Treat >=2 as a tooling
# failure so a broken rg cannot report a clean audit having checked nothing.
# Matches go to stdout; no-match yields empty output.
rg_scan() {
  local out rc=0
  out=$(rg "$@") || rc=$?
  if [ "$rc" -ge 2 ]; then
    echo "rg failed (exit $rc): rg $*" >&2
    exit 2
  fi
  printf '%s' "$out"
}

# Guard against anchor drift: if a guarded symbol is renamed away, its rg match
# set goes empty and the block below would pass having checked nothing. Assert
# the set is non-empty and still contains the symbol's canonical definition
# file(s); exit 2 (tooling error) otherwise.
require_anchor() {
  local raw=$1 label=$2
  shift 2
  if [ -z "$(printf '%s\n' "$raw" | grep -v '^$' || true)" ]; then
    echo "anchor drift: no '$label' matches; symbol renamed or removed" >&2
    exit 2
  fi
  local anchor
  for anchor in "$@"; do
    printf '%s\n' "$raw" | grep -qF "$anchor" || {
      echo "anchor drift: '$label' no longer found in $anchor" >&2
      exit 2
    }
  done
}

violations=0

echo '=== scanOnce call sites (must be only the port, adapter + ScanSpWalletUsecase) ==='
scanonce_raw=$(rg_scan -nF 'scanOnce(' lib/)
printf '%s\n' "$scanonce_raw"
require_anchor "$scanonce_raw" 'scanOnce(' \
  'lib/features/sp/domain/repositories/sp_account_repository.dart' \
  'lib/features/sp/data/bwk_sp_account_repository.dart'
bad=$(printf '%s\n' "$scanonce_raw" \
  | grep -v '^$' \
  | cut -d: -f1 | sort -u \
  | rg -vxF 'lib/features/sp/domain/repositories/sp_account_repository.dart' \
  | rg -vxF 'lib/features/sp/data/bwk_sp_account_repository.dart' \
  | rg -vxF 'lib/features/sp/domain/usecases/scan_sp_wallet_usecase.dart' \
  || true)
if [ -n "$bad" ]; then
  echo "FAIL: scanOnce called from forbidden file(s):"
  echo "$bad"
  violations=$((violations + 1))
fi

echo ''
echo '=== ScanSpWalletUsecase users (must be only definition, locator, cubit, and comments) ==='
usecase_raw=$(rg_scan -nF 'ScanSpWalletUsecase' lib/)
printf '%s\n' "$usecase_raw"
require_anchor "$usecase_raw" 'ScanSpWalletUsecase' \
  'lib/features/sp/domain/usecases/scan_sp_wallet_usecase.dart'
# Code references only: drop comment lines (// /// *) so doc comments that merely
# name the use case (incl. FRB-generated docs) do not trip the check.
bad=$(printf '%s\n' "$usecase_raw" \
  | rg -v '^[^:]+:[0-9]+:[[:space:]]*(///|//|\*)' \
  | cut -d: -f1 | sort -u \
  | grep -v '^$' \
  | rg -vxF 'lib/features/sp/domain/usecases/scan_sp_wallet_usecase.dart' \
  | rg -vxF 'lib/features/sp/sp_locator.dart' \
  | rg -vxF 'lib/features/sp/presentation/sp_cubit.dart' \
  || true)
if [ -n "$bad" ]; then
  echo "FAIL: ScanSpWalletUsecase referenced from forbidden file(s):"
  echo "$bad"
  violations=$((violations + 1))
fi

echo ''
echo '=== SpCubit.scan() call sites (must be only SP UI handlers + the cubit itself) ==='
# `\.scan\b` catches tear-offs (onPressed: cubit.scan) and two-step reads, not
# just `<SpCubit>().scan(`. `\b` stops it matching `.scanOnce` (its own block).
# Scoped to files that reference SpCubit so unrelated `.scan` (ledger BLE scan,
# import route enums) is ignored; comment/log lines are dropped.
spcubit_files=$(rg_scan -l 'SpCubit' lib/)
require_anchor "$spcubit_files" 'SpCubit' \
  'lib/features/sp/presentation/sp_cubit.dart'
scan_line_files=$(rg_scan -n '\.scan\b' lib/ \
  | rg -v '^[^:]+:[0-9]+:[[:space:]]*(///|//|\*)' \
  | cut -d: -f1 | sort -u || true)
bad=$(comm -12 \
    <(printf '%s\n' "$spcubit_files" | grep -v '^$' | sort -u) \
    <(printf '%s\n' "$scan_line_files" | grep -v '^$' | sort -u) \
  | rg -v '^lib/features/sp/ui/' \
  | rg -vxF 'lib/features/sp/presentation/sp_cubit.dart' \
  || true)
if [ -n "$bad" ]; then
  echo "FAIL: SpCubit.scan() reached outside SP UI file(s):"
  echo "$bad"
  violations=$((violations + 1))
fi

echo ''
echo '=== Autoscan lifecycle / background hooks that reach a scan (must be empty) ==='
# Some of these hooks now have legitimate non-scan uses in SP/sync (the sync
# foreground AppLifecycleListener, the cubit resubscribe Timer, the scan-page
# elapsed-tick Timer, StatefulWidget initState), so bare presence is not a
# violation. Flag a file only when a lifecycle/background hook co-occurs with a
# scan trigger the blocks above do not allowlist. Those blocks are the primary
# gate; this is defense in depth and still relies on human review for a hook
# that routes to a scan through an untracked indirection.
lifecycle_hooks='WidgetsBindingObserver|onResume|onForeground|Workmanager|AppLifecycleListener|initState|addPostFrameCallback|Timer'
hook_files=$(rg_scan -l "$lifecycle_hooks" lib/features/sp lib/core/sync)
scan_trigger_files=$(rg_scan -l 'scanOnce|ScanSpWalletUsecase|\.scan\b' lib/features/sp lib/core/sync)
bad=$(comm -12 \
    <(printf '%s\n' "$hook_files" | grep -v '^$' | sort -u) \
    <(printf '%s\n' "$scan_trigger_files" | grep -v '^$' | sort -u) \
  | rg -v '^lib/features/sp/ui/' \
  | rg -vxF 'lib/features/sp/presentation/sp_cubit.dart' \
  | rg -vxF 'lib/features/sp/data/bwk_sp_account_repository.dart' \
  | rg -vxF 'lib/features/sp/domain/usecases/scan_sp_wallet_usecase.dart' \
  | rg -vxF 'lib/features/sp/domain/repositories/sp_account_repository.dart' \
  || true)
if [ -n "$bad" ]; then
  echo "FAIL: lifecycle/background hook co-located with a scan trigger:"
  echo "$bad"
  violations=$((violations + 1))
else
  echo "PASS: no lifecycle/background hook reaches a scan trigger in SP or sync code"
fi

echo ''
if [ "$violations" -ne 0 ]; then
  echo "RESULT: SP invariant audit FAILED ($violations check(s) failed)."
  exit 1
fi
echo 'OK: SP invariant audit passed.'
