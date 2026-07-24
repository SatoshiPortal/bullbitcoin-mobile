# Compact Block Filters spike runbook

This runbook executes PR 1 of `compact-block-filters-pr-roadmap.md`. The harness is not registered in the app locator or router and is skipped unless explicitly enabled.

## Security requirements

- Use a dedicated testnet mnemonic with no production value.
- Never commit the mnemonic or include it in logs, screenshots, CI artifacts, shell history exports, or issue reports.
- Android and iOS app processes do not inherit shell environment variables. Device runs require `--dart-define`, which embeds the test mnemonic in the test binary; delete that binary after the run and never upload it.
- Reuse a `CBF_SPIKE_RUN_ID` only with the same mnemonic. A different mnemonic requires a different run id or deletion of the previous temporary directory.
- The harness emits only event stage, chain height, filter percentage, and warning code. Native warning payloads are intentionally discarded.

## Unit verification

```sh
fvm flutter test test/core_test/wallet/cbf_spike_support_test.dart
fvm flutter analyze --fatal-warnings --fatal-infos
```

## Demo/beta APK with the developer flag baked in

`make android-cbf-debug` builds a debug APK (production flavor, unsigned
like any local debug build) compiled with `--dart-define=ENABLE_CBF=true`.
Output: `./BULL-cbf-debug.apk` (host-extracted from the container build,
same path pattern as `make android debug` → `./BULL-debug.apk`).

`ENABLE_CBF` makes `CheckCompactBlockFiltersAvailableUsecase.execute()`
return `true` without requiring developer mode to be turned on in
Settings, so this one APK can demo the wizard's private-sync step and the
developer per-wallet sync-backend tile without also exposing unrelated
developer-only features. Tor still refuses CBF regardless of this flag
(`useTorProxy` short-circuits availability to `false`).

This flag is reserved for an explicit beta/debug build. It must never be
set on a production release build ahead of the compact-block-filters
rollout approval — see `docs/compact-block-filters-pr-roadmap.md`. Only
`android-cbf-debug` sets it; `android`/`release`/`debug`/`beta` are
unaffected. The makefile pins `MODE`, `FLAVOR`, and `DART_DEFINES` for this
target with `override`, so even `make android-cbf-debug MODE=release`
cannot escalate it to a release build — it always builds debug/production
with `ENABLE_CBF=true`.

## Manual APK smoke test

1. In the wizard, enable **Compact Block Filters (CBF)**. The mnemonic discovery step still uses Electrum intentionally; CBF starts only after the recovered wallet has been created.
2. Finish the mnemonic recovery, open the recovered Bitcoin wallet, and pull to refresh while keeping the app in the foreground.
3. Confirm that the wallet detail screen shows **Compact block filter sync**, first connecting to peers and then scanning the blockchain with progress. This card is emitted only by the CBF backend; an Electrum sync never renders it.
4. Open that wallet's settings and confirm that **Compact block filter sync** is switched on. If the switch is off after recovery, the wizard choice was not applied to the imported wallet.
5. Let the scan complete and compare the confirmed balance and transaction history with the same wallet synced through Electrum. A successful completion is shown briefly before the progress card is removed.
6. Put the app in the background during another CBF refresh. The foreground CBF attempt must stop. Return to the app and pull to refresh to start a new attempt.
7. Confirm the intentional V1 limitations: an incoming unconfirmed transaction does not appear until its first confirmation, Payjoin is unavailable for this wallet, and enabling Tor prevents CBF sync. Normal sends still broadcast through Electrum.

Seeing only the enabled settings switch proves that CBF was selected, not that a CBF scan completed. Seeing the CBF-specific progress card followed by a matching confirmed balance/history is the required functional evidence.

## Desktop smoke test

Environment variables are supported for a host-side Linux smoke test:

```sh
RUN_CBF_SPIKE=true \
CBF_SPIKE_MNEMONIC="$CBF_TESTNET_MNEMONIC" \
CBF_SPIKE_RUN_ID="linux-smoke-01" \
fvm flutter test integration_test/cbf_testnet_spike_test.dart \
  --dart-define=CBF_SPIKE_RECOVERY=false
```

`CBF_SPIKE_RECOVERY=false` uses `SyncScanType` for a fast connectivity smoke test. It does not validate historical recovery.

## Android or iOS recovery test

```sh
fvm flutter test integration_test/cbf_testnet_spike_test.dart \
  -d <device-id> \
  --dart-define=RUN_CBF_SPIKE=true \
  --dart-define=CBF_SPIKE_MNEMONIC="$CBF_TESTNET_MNEMONIC" \
  --dart-define=CBF_SPIKE_RUN_ID="<device>-recovery-01" \
  --dart-define=CBF_SPIKE_RECOVERY=true
```

Recovery currently uses `SegwitActivationRecoveryPoint` and `usedScriptIndex: 100`. This is deliberately a spike default, not a production recovery policy. The production birthday-to-`BlockId` decision remains gated by the results.

## Persistence and restart

The harness stores the BDK wallet and Kyoto data below a deterministic system-temporary directory derived from `CBF_SPIKE_RUN_ID`. It calls `wallet.persist()` after applying every CBF update. Run the same command twice to test a warm restart, then force-stop the app during connection, progress, and update application as described in Phase 0 of the implementation plan.

The data is retained intentionally for restart testing and contains the test wallet's private descriptor. Delete it after the run using platform tooling. Do not reuse the retention pattern in production; production secrets remain governed by Bull's secure-storage architecture.

## Required device report

Record one row per run without wallet, peer, address, descriptor, transaction, or mnemonic data.

| Field | Value |
|---|---|
| Platform / OS | |
| Device model | |
| App build mode | debug / profile / release |
| Network | Wi-Fi / cellular |
| Scan type / checkpoint | |
| Cold or warm start | |
| Time to first event | |
| Time to first progress | |
| Total time | |
| Peak data directory size | |
| Shutdown result | |
| Restart result | |
| Confirmed parity vs Electrum | pass / fail |
| Warnings by sanitized code | |
| Notes | |

## Current local status

- Flutter was bumped from 3.44.2 to the already-installed 3.44.6 across the root and workspace packages.
- The pure mapper and shutdown-guard tests pass.
- Whole-project analysis passes with fatal warnings and infos.
- The Linux integration build is blocked in the current container by missing GTK 3 development libraries. This is an environment limitation, not a Dart compile error.
- No Android or iOS device is connected in the current environment; all mobile and real-network Phase 0 gates remain pending.

## Stop condition

Do not start the Drift migration or production CBF backend PR until the mandatory Phase 0 device matrix has a reviewed go decision. A red integrity, confirmed-parity, or lifecycle gate blocks production integration; a red optional capability keeps that capability on Electrum or disables it for CBF wallets.
