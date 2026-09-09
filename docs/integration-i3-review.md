# I3 implementation review

Reviewed on 2026-09-09, on `integration/bullvault-metadata-deterministic-keys-v2`. Scope: `4e66ecbc7..3a675491f`, including `cf8490d44`, plus the surrounding persistence, publication, recovery, and startup paths needed to assess this change.

## Verdict

No additional blocking defect found in I3. Safe to continue the planned integration work; **not release-ready** and not approval of the whole stack. The full workspace test run passed: 3,201 root tests plus 179 package tests, 3,380 total. Whole-project analysis, formatting, fix dry-run, and the bull_ui boundary check also passed.

This was one reviewer, applying the architecture, evidence, Dart/Flutter, UX, simplification, scope-control, and AGENTS.md lenses plus security. The Bull Bitcoin review skill normally calls for multiple agents; the user's explicit solo-review instruction took precedence. There was no independent reviewer or emulator run. The earlier Kumulynja checklist helped keep the implementation on existing infrastructure and remove an unnecessary transitive import.

## Existing findings that remain open

These predate I3 and are not regressions introduced by the backup-change notification. Their planned integration chunks must not be skipped because this chunk passed.

### High: a retained Payjoin signing callback can outlive the private session

Follow-up: fixed in `385e59c6a`, including same-wallet re-unlock and awaited signing/fee-bump races. See the [I4 execution record](integration-execution.md#i4-continuation--revoke-signing-work-when-its-private-session-ends) for reproduction, native signing tests, final 3,391-test workspace result, and remaining limits. The evidence below describes the original I3 review baseline.

Evidence: `lib/core/wallet/data/payjoin_wallet_adapter.dart:66` obtains private material and returns the datasource callback. `lib/core/wallet/data/datasources/bdk_wallet_datasource.dart:204` captures a private BDK wallet and signs when that callback is later invoked, without consulting the session again.

Scenario: a passphrase wallet creates the callback while unlocked, the app locks or backgrounds, and the already-created callback is subsequently invoked with a signable proposal. Clearing the Dart session does not revoke the captured native signing wallet. Testing callback construction after lock does not test this scenario.

Required I4 work: bind private signing work to the session lifetime and reject invocation after that lifetime ends, including lock followed by unlocking the same wallet. Add an invocation-after-lock regression test. Also exercise lock during awaited signing preparation: `lib/core/wallet/data/repositories/bitcoin_wallet_repository.dart:206` checks the session before subsequent awaits and eventually signs at line 341. The callback finding is supported directly by source; native post-lock signing was not reproduced in this review.

### High: the BullVault mobile-passphrase form does not await capture protection

Evidence: `lib/features/bullvault/ui/bullvault_onboarding_screen.dart:821` starts `enableScreenPrivacy()` without awaiting its result, while the form builds immediately at line 841.

Scenario: capture protection is delayed or fails, but the passphrase form is already interactive. A user can enter or reveal a secret before protection is confirmed. An obscured initial field is not a fail-closed protection gate.

Required I5 work: use the established confirmed privacy gate for this form and cover delayed enablement, failure, and disposal while enablement is pending. No native capture experiment was performed here; this finding is based on the ungated rendering path.

### Architecture: recovery features still form a dependency cycle

Evidence: `lib/features/recoverbull/recover_remote_keychain_usecase.dart:2` imports WalletBackup; `lib/features/wallet_backup/wallet_backup_locator.dart:24` imports BullVault; `lib/features/bullvault/bullvault_locator.dart:46` imports RecoverBull. `FEATURES.md:101` now documents the previously omitted WalletBackup → BullVault edge.

Impact: extracting these features into the intended acyclic packages cannot preserve the present graph. It also couples backup startup to peer-feature construction, which is why I3 explicitly defers facade lookup and starts triggers after registration. This is not evidence that the current app necessarily crashes on startup.

Required I5 work: compose the recovery coordination at the app boundary in a separate scoped change, rather than adding another registry or event framework. Existing facade read/codec calls at `lib/features/bullvault/public/bullvault_facade.dart:45` also bypass use cases; reuse the owner's use cases while doing that boundary cleanup. The new watch method itself goes through a use case.

## I3 checks and evidence

| Concern | Result |
| --- | --- |
| Missing revision | Reproduced before implementation: a saved vault had no backup-state row. The new test expected revision 1 and failed with null; it now passes. |
| Atomicity | Save/delete call the existing revision recorder inside their SQL transaction. Ben's outer activation/linking transactions still contain all nested saves and wallet visibility updates. A forced revision-write failure rolls the vault write back. |
| Notifications before commit | The source is a Drift query, not an eager event emitted from inside `save`. Tests pause an outer transaction, verify no notification, then force rollback and verify neither data nor revision escaped. |
| Renewal | An actual SQLite trigger fails the visibility write after both generation updates. Statuses, revisions, and notifications remain unchanged. A successful retry commits both generations and emits one projected change. |
| Mutation coverage | Production vault-table writes found by repository-wide search are in the datasource's save/delete methods. The table has no wallet foreign-key cascade that silently bypasses them. Reservation writes are a separate, unbacked-up table. |
| Compared fields | Projection covers wallet reference, lineage, generation, status, and recovery-package text. Network and predecessor are encoded in that package. Wallet labels remain on the wallet-preference path. Dart record equality compares these scalar values, not list identity. |
| No-op behavior | Tests independently change each represented field. Setup flags, missing deletes, generation reservations, and repeated activation leave the revision unchanged. Sorted query rows prevent ordering-only notifications. |
| No double counting | Vault events enter `recordedChanges`, which only wakes publication. The automatic activation test verifies exactly one revision increment. |
| Startup | The first query result is deliberately retained as a wake-up. Triggers start after BullVault registration, and facade resolution is lazy. Graph restart after an unobserved committed write publishes the dirty record. This is not a disk-reopen or process-kill test. |
| Change during upload | A barrier pauses a real encrypted publication at the fake server. A newer vault status commits meanwhile; the runner performs another store and the final decrypted snapshot contains the newer status. |
| Recovery interaction | Remote/file recovery and publication enter the same runner through WalletBackupFacade. Restore notifications queue publication behind recovery; the existing recovery fence is checked before publishing. No second uploader was introduced. Actual BullVault restore ownership/status semantics remain I5. |
| Remote contents | Automatic tests decrypt the stored ciphertext and check vault identities, statuses, generation ordering, and the canonical persisted package. The remote server is a fake, not a live backend. |
| Secret exposure | I3 adds no mnemonic/passphrase/private-key reads, payload logging, analytics, or plaintext transport. The outward event carries no payload; stream-error logging uses the exception type. Existing encryption and descriptor validation are reused, not independently re-audited as cryptographic protocols. |
| Consent/offline behavior | Existing publication checks still refuse work when backup is disabled or recovery is fenced. Failed publication does not acknowledge the revision. Startup, resume, sync, or later changes can wake the existing runner; this change does not add a timed background retry service. |
| Simplification | Existing recorder, SQL transactions, stream merging, and job runner are reused. One nine-line use case preserves the repository's required boundary. No dependency, schema, queue, event bus, destination, or UI was added. |

## Adversarial recheck and test integrity

- Returning a typed `Err` from a Drift transaction does not itself roll it back. The relevant lifecycle methods were checked: rejection branches precede mutations; failures after writes throw and reach the outer transaction boundary. No post-write `Err` path requiring a new rollback mechanism was identified in these methods.
- The mapper decodes and normalizes descriptor checksums. A new test initially compared against an unchecked fixture string; comparing against the canonical persisted recovery package is the correct oracle. Production creation uses the descriptor parser's result (`create_bullvault_usecase.dart:272`), not that unchecked fixture. No existing expected wallet identity or status was changed.
- The first complete run timed out in the new multi-publication crypto test under the default 30-second deadline. It was stopped and is not counted as a pass. The follow-up adds a bounded two-minute file timeout; assertions and production behavior are unchanged. The complete rerun passed. This is not a performance benchmark.
- Adding `.distinct()` after converting to `Stream<void>` would suppress real changes. Distinctness is correctly checked on the projected records before discarding their values.
- Watching the whole sorted vault projection costs a read on table invalidation. Given this scoped change, no evidence justified a new event journal, cache, or indexing framework. Setup-only writes may cause a query, but unchanged projections do not wake publication.
- No old tests were deleted or assertions relaxed. The harness's optional real-vault section retains the old defaults for existing tests. The new automatic tests prove persistence and publication, not real descriptor import: their restore callback intentionally returns a failure and is not exercised by these scenarios.

## Verification and limits

- `make unit-test`: exit 0; root 3,201, bull_logger 7, bull_payjoin 77, bull_tor 27, bull_ui 40, bull_ui_catalogue 1, primitives 17, screen_privacy 10.
- Focused storage/publication/durability tests: 42 passed. Earlier storage/repository run: 23 passed.
- Whole-project analyze: no issues. Fix dry-run: Nothing to fix. Tracked-source formatting: no changes. Normal pre-commit hooks passed for both implementation commits.
- Final suite log: `/tmp/bbm-i3-unit-tests-final.log`. These local logs are not durable CI artifacts.
- No emulator boot/install, process-kill recovery, real-server recovery, Nostr publication, Bitcoin transaction, hardware signer test, or independent cryptographic audit was performed in I3.
- Final two-way restack fidelity, canonical seed ownership, real restore/lifecycle integration, and device checks remain required. Published-schema convergence remains I7. The distributed backup backend and the new recovery UI have not been implemented by this change.

No production edits were required by this follow-up review. Continue with I4, then I5 and the remaining integration gates before transplanting distributed production entry points.
