# Compact Block Filters PR roadmap

This roadmap is the implementation handoff. It turns the feasibility study into small, reviewable branches. Each PR is independently testable and must not absorb work assigned to a later PR.

The executable PR 1 instructions and device report template are in `docs/compact-block-filters-spike-runbook.md`.

The executable spike instructions and current pass/pending matrix are in `docs/compact-block-filters-spike-runbook.md`.

## V1 summary

V1 adds an opt-in Bitcoin sync backend that uses BDK compact block filters in the foreground. It keeps Electrum for transaction broadcast and the existing mempool API for fees. It does not add Tor, background execution, global 0-conf discovery, P2P broadcast, or automatic migration of existing wallets to CBF.

The user-facing value proposition is simple: Bull checks Bitcoin history locally instead of sending wallet addresses to one scan server. The product copy must also state that V1 does not hide the user's IP and that incoming payments appear after confirmation.

## Global implementation guardrails

- Start each branch from the last approved dependency shown below; do not stack unrelated migrations, FFI, UI, or platform work in one diff.
- Keep Electrum as the default and as the Bitcoin broadcast backend throughout V1.
- Keep Liquid unchanged.
- Do not expose `bdk_dart` types outside `data/`.
- Never log descriptors, scripts, addresses, wallet ids, peer IPs, seeds, mnemonics or transaction material.
- Do not add Tor or WorkManager/BGTask CBF execution opportunistically.
- Do not claim that a local unconfirmed transaction is still present in remote mempools.
- Run whole-project checks through the makefile and pinned FVM SDK.
- Stop the implementation when a prerequisite gate is red; document the result instead of adding a workaround that weakens privacy or integrity.
- The only compile-time bypass of the developer-mode gate is `ENABLE_CBF` (`--dart-define=ENABLE_CBF=true`, built via `make android-cbf-debug`, output `./BULL-cbf-debug.apk` — see `docs/compact-block-filters-spike-runbook.md`). It is read solely by `CheckCompactBlockFiltersAvailableUsecase` and the developer per-wallet tile's visibility check. Never set it on a production release build ahead of rollout approval, and never add a second place that reads it.

## PR 0: research and decision record

**Branch:** `docs/cbf-feasibility-plan`

**Title:** `docs(wallet): document compact filter feasibility and rollout`

**Description:**

```markdown
## Summary

Document the feasibility, limitations, UX model, technical design, and atomic rollout plan for BDK compact block filters in Bull Bitcoin Mobile.

## Why

Compact block filters improve wallet-script privacy but change synchronization, mempool visibility, lifecycle, and recovery behavior. We need an explicit decision record before changing production code.

## Scope

- Record the verified `bdk_dart` CBF API and upstream limitations.
- Define the foreground-only V1 and Electrum broadcast boundary.
- Document 0-conf, RBF/CPFP, Payjoin, peer, storage, and mobile risks.
- Define pass/fail spike gates and atomic follow-up PRs.

## Testing

- `git diff --check`

No application behavior changes.
```

## PR 1: non-production CBF spike

**Depends on:** PR 0

**Branch:** `spike/wallet-cbf-testnet`

**Title:** `test(wallet): validate compact filter sync on mobile`

**Description:**

```markdown
## Summary

Add a non-production testnet harness that validates the pinned `bdk_dart` compact block filter implementation on Android and iOS.

## Why

The Dart binding exposes CBF but has no first-party mobile example or Dart integration coverage. Production work must be gated on persistence, lifecycle, privacy, and wallet-state parity.

## Scope

- Exercise `CbfBuilder`, `CbfNode`, `CbfClient`, progress, warnings, updates, and shutdown.
- Validate recovery points, forced restart, concurrent isolate/thread access, and local unconfirmed transaction reconciliation.
- Compare confirmed wallet state with an Electrum control wallet.
- Test Payjoin prevouts against bdk-kyoto issue #136.
- Capture clearnet traffic to confirm wallet scripts and addresses are not transmitted.
- Produce the pass/fail report defined in the implementation plan.

## Excluded

- Drift migrations
- User settings or UI
- Tor and background execution
- Production backend selection

## Testing

- Integration tests on testnet
- Instrumented Android and iOS device runs
- `make analyze`
- `make unit-test`
```

**Implementation guardrails:** Keep the harness unreachable from release UI. Use dedicated testnet descriptors only. Do not weaken a failed criterion to obtain a go result.

## PR 2: wallet backend persistence

**Depends on:** PR 1 go decision

**Branch:** `feat/wallet-sync-backend-schema`

**Title:** `feat(wallet): persist the bitcoin sync backend`

**Description:**

```markdown
## Summary

Persist an Electrum or compact-filter sync backend for each Bitcoin wallet while keeping every existing wallet on Electrum.

## Why

Backend selection must be explicit, reversible, and scoped per wallet. It must not be inferred from global settings or silently change existing wallets.

## Scope

- Add the domain `BitcoinSyncBackend` enum.
- Extend `WalletMetadatas` and `WalletMetadataModel`.
- Add the schema 13 to 14 migration with `electrum` as the non-null default.
- Update metadata mappers and migration snapshots.
- Add migration and round-trip tests.

## Excluded

- CBF network calls
- Wizard and onboarding UI
- Sync behavior changes

## Testing

- `make drift-migrations`
- Migration tests from supported snapshots
- `make analyze`
- `make unit-test`
```

**Implementation guardrails:** Extend the existing metadata model and table; do not introduce a second wallet-metadata abstraction. Do not migrate any existing row to CBF.

## PR 3: additive wallet sync contract

**Depends on:** PR 2

**Branch:** `refactor/wallet-sync-contract`

**Title:** `refactor(wallet): add a typed wallet sync contract`

**Description:**

```markdown
## Summary

Introduce an additive domain contract for wallet synchronization and progress while preserving the existing Electrum behavior.

## Why

CBF is long-running, cancellable, and progressive. Raw BDK events must not leak into presentation, and the existing concrete repository debt must not be copied into the new path.

## Scope

- Add `WalletSyncRepository` under `domain/repositories/`.
- Add sealed sync progress, warning, and failure types.
- Adapt the current Electrum path to the contract without changing behavior.
- Add use-case and repository tests.

## Excluded

- Global refactor of `WalletRepository`
- CBF implementation
- UI and schema changes

## Testing

- Existing Electrum sync tests
- New repository and use-case tests
- `make analyze`
- `make unit-test`
```

**Implementation guardrails:** Keep the contract additive. Do not migrate unrelated wallet exceptions or repositories in this PR.

## PR 4: CBF data backend behind a developer flag

**Depends on:** PRs 2 and 3

**Branch:** `feat/wallet-cbf-backend`

**Title:** `feat(wallet): add the compact filter sync backend`

**Description:**

```markdown
## Summary

Add a foreground-only compact block filter datasource behind a developer flag while keeping Electrum as the default backend and broadcast transport.

## Why

This is the smallest production-shaped integration that proves session ownership, persistence, recovery, and backend routing without exposing unfinished UX.

## Scope

- Add `CbfWalletDatasource` and map BDK info/warnings to domain types.
- Enforce one active native session per wallet.
- Persist CBF data per wallet and network.
- Apply and persist wallet updates.
- Implement cancellation and lifecycle-safe shutdown.
- Route Bitcoin sync by `BitcoinSyncBackend`.

## Excluded

- Wizard and end-user activation
- Tor and background execution
- P2P broadcast
- Global mempool tracking

## Testing

- Session, mapping, cancellation, and persistence tests
- Testnet integration tests from PR 1
- Electrum regression tests
- `make analyze`
- `make unit-test`
```

**Implementation guardrails:** Handle all four `Info` subclasses. Make Bull cancellation idempotent because native shutdown is not. Do not add `socks5Proxy` in this PR: the pinned binding lacks `onlyConfiguredPeers()`, so Kyoto's DNS bootstrap would still leak in the clear when configured peers fail, making a Tor claim false. When `useTorProxy` is enabled in settings, refuse to start a CBF session unless the caller passed an explicit acknowledgement flag.

## PR 5: reusable sync progress UI

**Depends on:** PR 3; can be developed in parallel with PR 4 after the progress contract is stable

**Branch:** `feat/bull-ui-sync-progress`

**Title:** `feat(ui): add determinate wallet sync progress`

**Description:**

```markdown
## Summary

Add a reusable Bull UI component and presentation states for determinate wallet synchronization progress.

## Why

The initial compact-filter scan can take time. Users need clear progress, recoverable actions, and honest pause/resume messaging instead of an indefinite spinner.

## Scope

- Add a determinate and indeterminate progress component to `bull_ui`.
- Add connecting, scanning, warning, cancelled, resumed, and completed presentation states.
- Add localized user-facing copy and accessibility semantics.
- Keep technical details in an optional secondary panel.

## Excluded

- Backend activation
- Wizard choices
- Background claims or platform services

## Testing

- Widget tests for 0%, progress, warning, offline, cancellation, resume, and 100%
- Accessibility and small-screen checks
- `make bull-ui-check`
- `make analyze`
- `make unit-test`
```

**Implementation guardrails:** Do not show raw BDK warning strings. Do not expose peer IPs, wallet ids, or descriptors. Do not create feature-local copies of the progress component.

## PR 6: wizard and default-wallet UX

**Depends on:** PRs 2, 4, and 5

**Branch:** `feat/wizard-private-bitcoin-sync`

**Title:** `feat(wizard): add private bitcoin sync onboarding`

**Description:**

```markdown
## Summary

Add an opt-in, one-action private Bitcoin sync choice and a resumable initial-sync experience for newly created default wallets.

## Why

CBF should make stronger wallet privacy approachable without exposing protocol complexity or blocking the user behind an unexplained loading screen.

## Scope

- Add the wizard choice through `WizardChoices`, `WizardField`, and `ApplyPendingWizardChoicesUsecase`.
- Persist a global default in `SettingsRepository` for new wallets only.
- Apply the choice in `CreateDefaultWalletsUsecase`.
- Show the non-blocking sync card, progress, pause/resume explanation, completion state, and Electrum fallback.
- Explain that addresses are not sent to one scan server, incoming payments appear after confirmation, and V1 does not hide the user's IP.
- When `useTorProxy` is enabled, block the CBF choice (or require an explicit confirmation, per the product decision) because V1 CBF traffic bypasses the Tor proxy that Electrum traffic uses.

## Excluded

- Existing-wallet migration
- Import and recovery flows
- Tor and background execution
- Production or beta exposure; the choice remains hidden outside the developer flag until PR 10

## Testing

- Wizard pending-choice and settings tests
- Onboarding BLoC and widget tests
- UX-state checklist from the implementation plan
- `make translations`
- `make analyze`
- `make unit-test`
```

**Implementation guardrails:** Keep every entry point behind PR 4's developer flag; this PR is inert for normal users until PR 10 validates gates G3/G4 and adds beta eligibility. The wallet screen must remain navigable while syncing. Never say the scan continues in the background.

## PR 7: own outgoing transaction continuity

**Depends on:** PR 4 and gate G3

**Branch:** `feat/wallet-cbf-unconfirmed-sends`

**Title:** `feat(wallet): preserve pending sends with compact filters`

**Description:**

```markdown
## Summary

Persist a successfully broadcast outgoing transaction in the local BDK graph for compact-filter wallets and reconcile it through confirmation, eviction, or replacement.

## Why

CBF does not observe the mempool. Without local insertion, pending history, change, RBF, and CPFP can disappear until confirmation.

## Scope

- Call `Wallet.applyUnconfirmedTxs()` only after successful Electrum broadcast.
- Persist the updated wallet graph.
- Reconcile confirmation, eviction, and replacement using BDK updates/events and `applyEvictedTxs()` where applicable.
- Preserve RBF and CPFP behavior when the spike proves it safe.

## Excluded

- Incoming 0-conf discovery
- Address-wide Electrum or mempool scans
- Claims that the transaction remains accepted by remote mempools

## Testing

- Restart, confirmation, eviction, replacement, RBF, CPFP, and spendability tests
- `make analyze`
- `make unit-test`
```

**Implementation guardrails:** Do not mark an untrusted output spendable manually. Do not insert before Electrum accepts the broadcast. If reconciliation is not reliable, stop and keep the confirmed-only behavior.

## PR 8: broadcast and Payjoin safety gates

**Depends on:** PR 4; required before enabling affected flows for beta

**Branch:** `test/wallet-cbf-transaction-safety`

**Title:** `test(wallet): guard CBF broadcast and Payjoin flows`

**Description:**

```markdown
## Summary

Lock the existing Electrum broadcast behavior and validate Payjoin prevout handling for compact-filter wallets.

## Why

Swap recovery depends on precise Electrum rejection errors, and bdk-kyoto issue #136 may prevent complete verification of foreign Payjoin inputs.

## Scope

- Test `missingorspent` and `non-final` with one and multiple Electrum servers.
- Ensure permanent broadcast rejection is not hidden by fallback.
- Trace and test Payjoin foreign prevouts, amounts, and fees.
- Keep Payjoin on Electrum or disable it for CBF wallets if verification is incomplete.

## Excluded

- Esplora, mempool API, or P2P broadcast replacement
- Unrelated swap refactors

## Testing

- Swap watcher and Electrum fallback tests
- Real Payjoin testnet scenario
- Security review
- `make analyze`
- `make unit-test`
```

## PRs 9a-9d: import and recovery support

These PRs are optional for the first beta and must remain separate because each feature owns its own use cases and tests.

| Branch | Title | Description focus |
|---|---|---|
| `feat/import-mnemonic-cbf` | `feat(import): support compact filters for mnemonic wallets` | Pass the backend choice through mnemonic import and validate recovery parity. |
| `feat/import-watch-only-cbf` | `feat(import): support compact filters for watch-only wallets` | Cover descriptor and xpub imports with validated recovery checkpoints. |
| `feat/hardware-wallet-cbf` | `feat(wallet): support compact filters for hardware imports` | Add only the approved hardware/QR flows and keep signing unchanged. |
| `feat/recovery-cbf` | `feat(wallet): support compact filters during recovery` | Use only spike-validated checkpoints and compare recovered funds with Electrum. |

**Shared description template:**

```markdown
## Summary

Add the already-validated compact-filter backend choice to this wallet import or recovery flow.

## Why

Each feature owns its orchestration and must adopt CBF without importing wallet data internals or changing unrelated flows.

## Scope

- Pass the backend through the feature use case.
- Reuse the shared progress UX.
- Apply only recovery points validated by the CBF spike.
- Keep Liquid and signing behavior unchanged.

## Testing

- Feature-specific use-case and presentation tests
- Recovered balance and history comparison with Electrum
- `make analyze`
- `make unit-test`
```

## PR 10: beta rollout

**Depends on:** PRs 2-6 and PR 8. It also depends on PR 7 when gate G3 is required for the selected beta profile; otherwise the beta copy must explicitly state confirmed-only pending-send limitations.

**Branch:** `feat/wallet-cbf-beta`

**Title:** `feat(wallet): enable compact filter sync for beta users`

**Description:**

```markdown
## Summary

Enable opt-in compact-filter synchronization for beta users with safe rollback and non-sensitive observability.

## Why

The backend and UX need controlled real-world validation before any default-on decision.

## Scope

- Add the beta feature flag and eligibility checks.
- Add aggregate timing, disk, resume, warning-class, and failure metrics.
- Add support copy, fallback guidance, and Electrum rollback.
- Keep existing wallets on Electrum unless the user explicitly opts in.

## Excluded

- Default-on rollout
- Tor and background execution
- Wallet addresses, scripts, descriptors, peer IPs, wallet ids, or transaction data in telemetry

## Testing

- Full `make checks`
- Android and iOS release-mode device matrix
- Security and privacy review
- Rollback rehearsal
```

## Deferred PRs

These are not part of V1 and must never be pulled into the branches above:

- `feat(wallet): route compact filter sync through Tor` — gated on GT: bump the `bull_sdk` bdk-ffi pin to a revision >= bdk-ffi PR #1047, use `onlyConfiguredPeers()` with an audited non-empty IP peer list plus `socks5Proxy(127.0.0.1:torProxyPort)`, handle node exit on `NoReachablePeers` (whitelist exhaustion stops the node instead of retrying), and prove zero clearnet DNS/connections with a packet capture. Without the pin bump this PR must not be attempted: Kyoto's DNS bootstrap is never proxied and re-fires when configured peers fail. Onion peers stay out of scope until bdk-ffi exposes non-IP peers.
- `chore(sdk): bump bdk-ffi pin for only_configured_peers` — small preparatory PR in `bull_sdk`, can land any time after PR 1 without activating Tor.
- `feat(android): continue compact filter sync in foreground service`
- `feat(ios): continue compact filter sync with system tasks`
- `feat(wallet): observe active incoming payments before confirmation`
- `feat(wallet): make compact filters the default sync backend`
