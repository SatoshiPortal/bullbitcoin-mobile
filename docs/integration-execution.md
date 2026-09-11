# Integration execution record

Started 2026-09-09. This is an execution log, not a release-readiness claim.

## Inputs and preservation

- Ben PR #2793: `309819e31ca49c73ab48701c8c3b274e3375d10f`, rechecked via GitHub on 2026-09-09.
- Audited core donor: `eaa5696f0a2533b6dd1474cd275e72dc484a6f46`; donor boundary `7ea4d7bfcdc86c100262f4c1d454ccbf0954d452`.
- Distributed donor: `7cf8694e6c5622c31fd2a779d36b247a910ba2d6`; unique-work inventory stays in the integration plan.
- Backend target: `SatoshiPortal/BULL-metadata-backup` master at `8cea0b52b2c397a4fd2558b26e93338693be083a`, verified via GitHub. The nearby base checkout is older (`31d66d2`); do not implement against it by assumption. Master explicitly retains protocol v1 after reverting audience-bound authentication.
- New core branch: `integration/bullvault-metadata-deterministic-keys-v2`.
- New worktree: `/home/francis/bbm-bullvault-integration-v2`.
- Original branches/worktrees remain untouched. The three untracked planning documents were copied with identical SHA256 hashes, not moved. The copies are retained on this new branch; their originals remain untracked and unchanged.
- Latest published release remains v6.13.1. Schema consolidation is a later explicitly scoped integration chunk; intermediate 16/17 numbering is not a release promise.

Original/copy document hashes:

| Document | SHA256 |
| --- | --- |
| distributed-backups-roadmap.md | 6a1f1cb49a29892103df34e96fa3477063f3ea59904bf84e2406a4db8a934229 |
| ben-upstream-integration-plan.md | fbe9b272da9da664c1132731cf09407bef10f61403cd36e75c1f053ef7821485 |
| bullvault-backup-recovery-ui-plan.md | 5d55d63ac77061fe50d7accc7364baa69553f64456748027d13bc62255bc846b |

## Approved decisions overriding older planning assumptions

The user's latest approval covers app and backend implementation, session-only imported recovery signers by default, a new integration branch, and real external tests using synthetic credentials/Nostr/testnet only. It does not authorize mainnet spending, production deployment, pushes or changing other worktrees.

The UI plan supersedes older roadmap access assumptions: eligible cosigner account-key input permits retrieving its server BIP138 copy without another user-held secret; a separately addressable password-encrypted descriptor server copy is required. Anyone holding that eligible account key has the same retrieval/decryption capability. This is not independent secret authentication, and must not be marketed as such.

Manual recovery has three entries (descriptor, cosigner public keys, magic backup words), with local encrypted files under descriptor import. Magic-word lookup uses Bull → Nostr → Bitcoin fallback. Automatic seed recovery derives the established credential and checks Bull; its home notification follows durable import, not merely discovery.

New recovery seed/passphrase imports stay session-only; an unrelated current mobile wallet is never replaced. Session expiration requires re-entry and removes signing capability without deleting the recovered public vault.

Review remains solo under the user's no-subagent instruction. The user's subsequent architecture correction explicitly rejects Kumulynja and skill-driven architecture changes: use the upstream repository's `ARCHITECTURE.md`, `AGENTS.md`, `FEATURES.md` and actual code as the authority. Historical checklist references below describe earlier work, not the current review procedure. No independent multi-agent review is claimed.

## New upstream delta

Ben rewrote several tip commits after the plan's `da6950a69` pin. The final tree adds optional last-resort activation timing, policy recognition/branch allocation, recovery-package schedule serialization, renewal constraints, UI and tests. Net delta: 18 files, +620/-36. The new base includes this implementation; do not recreate catastrophic recovery or strip its descriptor branch while adapting backups.

## Core transplant manifest

Replay is complete. The table was reconciled against the actual 31-commit Git history: only the share-sheet-success donor was excluded. Nontrivial adaptations are recorded below. Final integration review remains pending; replay does not mean release-ready.

| Donor commit | Subject | Disposition |
| --- | --- | --- |
| `83957abb81a5032bcbb0245b508d2c83e092ef41` | feat(storage): backup schema v15 and secret redaction foundations | Replayed as `bd6d90bfcbc4dc951691959be0903fd49f475a93`; final review pending |
| `36d53636aec9a9c4edfc94a2fca001e9c4eb4300` | feat(nostr_identity): bip85 reservations and backup identity keys | Replayed as `92be4831bd529932cada7ced59622d59a7b74f11`; final review pending |
| `560fd4249efcdf7f9e4ad25ed772eef2ebb597a4` | feat(keychain_manifest): wallet inventory and nostr key records | Replayed as `2ea0f982c407b83d5ea2b2005a73e14b0a2eaf23`; final review pending |
| `ac40db6ab62e4cdcaa08b6a6cdb87371de05a755` | feat(wallet_backup): typed backup document protocol and codec | Replayed as `8c9cd622c93f76fc0e2b8aac97e0fcc1984185fa`; final review pending |
| `d7f6d1129af6603c01a21796f07ccc629071edf2` | feat(wallet_backup): backup engine, job runner and recovery | Replayed as `a001d789b486d0d8653122878352decc29148220`; final review pending |
| `b8d96aec17cb4bc5267ec4cbc1edd0216a4f5af3` | feat(backup_settings): failure taxonomy and backup use cases | Replayed as `99c959c8f2ee6df2a0b9630bb02e9ca9887d96cb`; final review pending |
| `2da65ef6bb8bc68c8ef83a7ea0cd8e78589d056e` | feat(wallet): wallet birthday and provenance at creation | Replayed as `fa73ee2bff8c0e3f11526c325cf6186caa5eeccd`; final review pending |
| `7e3fefbaa1b8cc07f4a314fc86590d4d89814671` | feat(wallet): wallet definitions backup and live backup engine | Replayed as `b5f3b758ef7190233bc13eb96062d0b23d26704a`; final review pending |
| `620bf3d9238b080c9e46a6b4afe4e0a37be07331` | feat(backup_settings): wallet backup file import and export | Replayed as `727bb278e642fe8210c5c36bf903ff9138a6845f`; final review pending |
| `4caa6bb1f4d44f737a8e08cadf2f97b1845dc3fb` | feat(backup_settings): data backup and wallet recovery UX | Replayed as `8467d8b1cdca06673ef7bb8e2d197d04b9c9e50c`; final review pending |
| `1081a97f1ae35fc3dd321f837addab98cbec2347` | feat(passphrase_wallet): passphrase wallets with private session | Replayed as `c592942e9ae174fbf3c17043c4afa8c998e003e2`; final review pending |
| `4915467e818a7753b0e33f37808cd3f807dbcda1` | fix(wallet): preserve recorded wallet refs on definition restore | Replayed as `94ed142474cdd98412729a48b7dd9adc66a7418b`; final review pending |
| `2a2352ac6dcb7e38be2427ea3fbe497f65095c87` | fix(wallet): resolve every signing key through the material resolver | Replayed as `63a4defab76793860d58254d0f105f6233cc3e6a`; final review pending |
| `e1b2bb321ecea403efcfba03a2442b235ef1b7fb` | chore: clear analyzer warnings left by the rebase | Replayed as `421f7d807a327025e72fa38f802339d362af5093`; final review pending |
| `f4a0133e22c8e323d730ca2ea81b95bb9aa96a97` | feat(wallet_backup): back up BullVault recovery packages and signer rosters | Replayed as `0d812557cee4062fdd95ff03bb2bbe720c83c574`; final review pending |
| `91b174fb3ab5ad452c97dfecb42be322b484daec` | feat(backup_settings): show and export BullVault recovery packages | Replayed as `6d647c3e94fc5ec5ea59fef89a2ce64f873ad3fe`; final review pending |
| `8a5b169515c1161990a1c0f61410548fcee9428e` | chore(rebase): follow feat/bullvault to b944ee811 | Replayed as `58cffe94b6982793abb5f4078ae7231d0863166f`; final review pending |
| `4844e984339d886f0dc6bf37988586d7671e1846` | fix(security): gate secret screens on confirmed capture protection | Replayed as `96909be63710f9dbc3049e424d2f880e15ff3d9d`; final review pending |
| `f8152a41f856e2c436cab564d5a1efa0613f1a65` | fix(bullvault): count the recovery package as exported once the share sheet was shown | Excluded: showing a share sheet is not proof of export; preserve Ben’s result check |
| `11c4400771edaaaf5ecef5d85722b799fae65da8` | feat(bullvault): hand the descriptor to a manual signer at registration | Replayed as `ab1835c8be9cc6db940eceaff033b96c47584442`; final review pending |
| `1b5d3c829fea28ca3d3577ee8b7d7384611bdda6` | fix(wallet_backup): say why enabling Data Backup was refused | Replayed as `c28e2e1ace99249db1f68c313128bfa57e6000cc`; final review pending |
| `dba79dcc2c0be4098188ba0ddb8600e6f6d62fad` | feat(onboarding): land on home while Data Backup is set up | Replayed as `509274057ce5b7a281a479f147ae29fbb91ab9bc`; final review pending |
| `d1e42efebeaa2937f675364506d9a1f0455ef404` | fix(recoverbull): remove the orphaned permission gate | Replayed as `d044a50a65a46b7872f3d91f2fea9451e27bd5e4`; final review pending |
| `dd04503cb99d154ff511bda9c6b34822994994b0` | fix(settings): restore the passphrase wallet entry | Replayed as `6de8250c88aedd6a936d67d2154933e02a24c65c`; final review pending |
| `0f5e892ce1ab6a7c3726890b6af603416f1aa713` | fix(wallet_backup): keep retained file recovery data dirty | Replayed as `c13c97581bd46ade63cfd93eaf27e2ca8df82e41`; final review pending |
| `b4427ce829bcbbba29be83baf818cdef4864f5fe` | fix(screen_privacy): require a positive capture-blocking response | Replayed as `2e379ea3a437b45331aef13c86363aa6f0e06222`; final review pending |
| `42de3be620239c8f0f1b1ba4f3f6f006978356cc` | fix(wallet): commit backup revisions with metadata changes | Replayed as `5ca30a41d9c98ab0537839c08c36534f6247ce70`; final review pending |
| `2f132e72090b02ab4b4ca55979ab664d480d590d` | fix(wallet_backup): acknowledge identical heads after lost replies | Replayed as `7c8f374ed6ed4d6d2c362d227ef036673539cfca`; final review pending |
| `e0edc364aa84e7f50d053f8222960ac6d931652d` | refactor(keychain_manifest): remove the unused restore policy | Replayed as `a86ed20076862bb69e0021ddeb5dde04e196d94b`; final review pending |
| `d34c4d1c02bde42c1d97b0661548d038fe9922b3` | fix(wallet_backup): fence conflicts before saving their checkpoint | Replayed as `c8bdd69b76276de5b38dfa2185d1b6987a2978c7`; final review pending |
| `548884f47e3f3bed62c8ed63d0f94c8aed2767f5` | fix(bullvault): align integration with upstream restore APIs | Replayed as `de2ba5e6cdda34b2d3410017a533f356e5c13590`; final review pending |
| `eaa5696f0a2533b6dd1474cd275e72dc484a6f46` | fix(core): gate signer input on screen protection | Replayed as `db084efbbe004cc54df6f6280c7f888c58dc5a0c`; final review pending |

## Conflict decisions and verification

- First storage slice: preserve Ben's schema-16 vault lifecycle tables and regenerate schema-17 derived artifacts from the merged schema. Do not concatenate generated Shape/column IDs or retain a schema-17 fixture lacking Ben's vault tables.
- First localization conflict: retain both Ben's appended restore/last-resort strings and the stack's passphrase-wallet label. This resolves history, not new localization copy.
- Toolchain: use the FVM launcher on its compatible host Dart with `/home/francis/.pub-cache/bin` added to PATH; FVM selects pinned Flutter 3.44.9. Putting the new SDK ahead of the old global FVM snapshot failed, so it is not the working invocation.
- Core replay finished at `db084efbbe004cc54df6f6280c7f888c58dc5a0c`: 31 commits retained from 32 donors. Generated-code compilation passed after the post-replay adaptations. No emulator or external-publication result is claimed.
- Default-seed lookup is Result-based, but remains inside Ben's mobile-key setup branch; hardware-only setup does not acquire a new app-seed dependency.
- Mnemonic display/verification retains the stack privacy gate and Ben's singleLocalSeedFingerprint boundary, rather than signer-0 compatibility getters. Transferred generated-inheritance PrivacyGate into Ben's extracted mnemonic flow; did not resurrect the deleted onboarding screen implementation.
- Removed the obsolete BullVault startup visibility-reconciliation call and backup adapter callback. Ben's SQLite lifecycle now owns atomic visibility. Backup restoration still needs real SQLite visibility/revision tests; removing the obsolete mock callback is not that proof.
- Added all-record enumeration to Ben's SQLite datasource/repository for backups, using his transaction wrapper rather than resurrecting the removed metadata lock.
- The old schema-alignment donor now changes only still-needed Result API call sites; its generated schema patch was superseded by generation from the merged schema in slice 1.
- Excluded donor f8152a41f: it treated share-sheet display, including cancellation/unavailable, as an exported recovery kit. This weakens Ben's check and contradicts the approved manual descriptor handoff. A later UI chunk provides explicit handoff routes instead.
- Retained Ben's BullButton/record-status settings routing rather than reintroducing the donor's obsolete button import.
- Backend worktree `/home/francis/bull-metadata-backup-recovery`, branch `feat/bullvault-recovery-records`, baseline `8cea0b52b2c397a4fd2558b26e93338693be083a`: `cargo test --all-targets --locked` passed 40 tests (38 unit + 2 startup). No backend application changes yet.
- `make deps` and `make drift-migrations` completed successfully; logs are in /tmp/bbm-integration-v2-*.log.

## Post-replay checks in progress

- Two-way patch comparison: the original durability patches (atomic metadata revisions, lost reply acknowledgement, conflict checkpoint fencing, retained recovery data dirtying) have equal patches in git range-diff. This is fidelity evidence, not a replacement for running their tests.
- The standalone screen_privacy package passed 10/10 tests in this worktree. Native platform/device verification remains pending.
- The first whole-project analyze was started before generation completed and reported missing generated types. It was not a valid compilation gate. After successful make build-runner/translations (including bull_payjoin), whole-project analysis passed with no issues.
- Added app-level tests for inheritance capture refusal/pending enable/disposal, recorded seed-origin wallet references, private-descriptor rejection/redaction, and actual PSBT signing through the volatile session with no persistent seed access. The focused tests pass; full-suite results are recorded separately below.
- Found and corrected stale mnemonic display/verification across wallet selection: FutureBuilder retained old words during a new load; verification accepted an obsolete async result. Added two focused widget tests. This is a separate post-replay security correction, not a claim that the donor patch already solved it.
- Updated restore test fixtures with unavailable mobile access because their wallets have no signing keys. Updated the real-signing legacy-wallet fixture to run the complete current migration before querying through current metadata models. Dedicated 15-to-16 migration tests retain their explicit version-16 assertions.

## Next core gates (not completed)

- I2 host regression gate: preserved durability tests passed in the 3,191-test root run on the merged schema. This is not the remaining I8 device/fidelity gate.
- I3: implemented and reviewed in the continuation below; all 3,380 workspace tests pass. Represented fields are wallet reference, lineage, generation, status and encoded recovery package; labels retain the existing wallet-preference path. This does not close I4/I5/I7/I8.
- I4: private-signing revocation is implemented and reviewed in the continuation below; all 3,391 workspace tests pass. The broader canonical-ownership/secret-type audit and device checks are not closed by this substep.
- I5: prove restore status/ownership/lineage behavior against actual SQLite, review remaining privacy lifecycle races, and remove the recovery dependency cycle through app composition.
- Concrete privacy follow-up: the retained Payjoin callback is now guarded and tested by the I4 continuation below. `lib/features/bullvault/ui/bullvault_onboarding_screen.dart:813` still enables protection without waiting before building the mobile-passphrase input; that I5 finding remains open.
- I8: full host checks, fidelity/scope review and isolated device checks before creating the distributed child branch. No app installation, public publication, backend record implementation or production readiness is claimed by this log.

## Additional integration findings and corrections

- Birthday no-op stores spuriously incremented the backup revision: DateTime equality distinguishes UTC/local notation and Drift stores whole Unix seconds. Reproduced against real SQLite (expected zero changes, got one), then compared at the actual storage precision. The test also proves a changed second and clearing the birthday still dirty the definition.
- Backup testing must update only matching local seeds, including nondefault wallets. The initial conflict resolution incorrectly required every wallet to match. Ben's nondefault/mixed-seed regression caught this. Corrected to reject zero matches and update only the matching subset; kept the failure and history expectations unchanged. Targeted RecoverBull tests: 4/4 passed.
- Raw unexpected Bitcoin-signing exceptions reached logs. A synthetic secret-bearing exception reproduced the leak through the actual public review entry point and captured debug logging. The handler now records the exception type plus stack, not its potentially secret-bearing message. The typed unexpected failure remains unchanged.
- The review checklist was applied solo under the explicit no-subagent constraint. No independent seven-agent review is claimed. These fixes add no production abstraction, dependency, schema revision or recovery protocol; the larger I3–I5/I8 gates above remain open.

## Verification evidence

Post-replay commits (all local, normal hooks enabled):

- `fb521d262`: BullVault API imports and restore fixture adaptations.
- `b999cc11b`: confirmed inheritance input protection and stale mnemonic-load rejection, with widget regressions.
- `ad17f4805`: RecoverBull matching-seed backup-history correction.
- `c8e2b2087`: persisted-precision birthday comparison and wallet-definition regression coverage.
- `0a9d808f2`: signing exception redaction and actual private-session PSBT regression coverage.

Results:

- Backend baseline: 40/40 tests; no backend code changed.
- Code generation: make drift-migrations, make build-runner translations passed, including bull_payjoin.
- Focused descriptor/inheritance privacy/stale-selection tests: 19/19 passed.
- RecoverBull backup-history tests: 4/4 passed after correcting the matching subset.
- Signing exception redaction: reproduced a failing assertion before the fix; the same test passed afterward. The assertion also requires a log entry, so suppressing all logging cannot satisfy it vacuously.
- Birthday dirtying: reproduced a failing real-SQLite no-op assertion before the fix; changed-second and cleared-birthday cases still record changes after the fix.
- First full root suite: 3,189 passed, two failures in backup-history verification. Both were corrected and independently retested. Final make unit-test run: root 3,191/3,191 passed; all seven workspace package suites passed (bull_logger 7, bull_payjoin 77, bull_tor 27, bull_ui 40, bull_ui_catalogue 1, primitives 17, screen_privacy 10). Total: 3,370 passed, zero failed.
- Final static checks: whole-project analysis, bull_ui import boundary, dart fix dry-run and tracked-source formatting passed. Each Dart commit also runs the normal pre-commit analysis/fix/format checks; hooks are not bypassed.
- Raw verification logs are under /tmp/bbm-integration-v2-*.log. These local files are not durable CI artifacts or independent review evidence.

## Milestone boundary

Core restack and the five post-replay corrections are committed locally. The donor mapping was checked programmatically against Git history (31 retained, one deliberate exclusion). All three copied planning documents still match their original hashes. Original donor HEADs remain `eaa5696f0` and `7cf8694e6`; the new backend worktree remains clean at its verified baseline.

That completed the restack/host-regression milestone, not the full integration or distributed recovery implementation. I3 follows below. Private capability lifecycle (I4), remaining restore/privacy/composition seams (I5), and the core device/fidelity gate remain next. Do not transplant distributed production entry points or claim release readiness before those gates. Final published-schema convergence (I7) also remains mandatory before release. No emulator build/install, external synthetic publication, backend record API or new recovery UI was completed in this milestone.

## I3 continuation — atomic BullVault backup changes

Implementation commit: `cf8490d44` (`fix(bullvault): record and publish committed backup changes`); test-timeout follow-up: `3a675491f`. Normal pre-commit checks passed for both. No push or deployment.

Reproduced the missing dirty revision before implementation: saving a vault left `wallet_backup_states` absent (expected revision 1, actual null). The targeted test now passes.

The existing BullVault SQL datasource now calls the existing storage revision recorder inside its save/delete transactions. Nested operations remain inside Ben's outer lifecycle transaction. A Drift query watches a sorted projection of the same represented fields and compares record values before emitting. Its first snapshot wakes the existing runner as well, avoiding a subscribe/initial-query race; later notifications see only committed state. The notification is passed through the owning repository, a small watch use case, and BullVault's public facade into `recordedChanges`. It does not increment the revision again.

| Mutation | Backup behavior |
| --- | --- |
| Create/save/delete a represented vault record | Record the revision with the SQL write; a missing-row delete is a no-op. |
| Initial activation / cancelled renewal | Status change records a revision. |
| Renewal activation / restored lineage linking | Each changed record records a revision inside the shared outer transaction; publication sees both generations together. |
| Restored record / recovery-package enrichment | Existing save path records changed package/lineage/generation facts. |
| Wallet label | Existing wallet-preference recorder and trigger remain responsible. |
| Setup confirmations, hardware setup flags, local ownership, generation reservations | Not serialized in the vault contribution; do not dirty it. |
| Internal wallet visibility | Not the backed-up `hideOnHome` preference; derived from vault lifecycle, and committed with the lifecycle status change. |

Backup triggers now start after BullVault registration in the app composition root. The new stream resolves the public facade lazily after graph construction. No new scheduler, event bus, schema revision, dependency, wire format, backup destination or UI was introduced.

Verification:

- Existing BullVault persistence suite plus new storage tests: 23 passed.
- Final focused storage/automatic-publication/durability baseline suites: 42 passed.
- Whole-project analysis, bull_ui import boundary and full tracked-source formatting passed; dart fix reports Nothing to fix. The final complete `make unit-test` exited 0: 3,201 root tests and 179 package tests, 3,380 total.
- Tests cover each represented field independently, no-op/setup-only changes, outer rollback, revision-write failure, renewal visibility rollback, automatic creation/activation/renewal/cancellation/deletion, restart of the application graph after an unobserved committed change, and a later change during an upload. The latter produces a second publication containing the newer status.
- Automatic-publication tests use real SQLite vault records, the real vault parser/codec, real backup serialization/encryption and the existing runner; the server and unrelated metadata/definition section owners remain test fakes. This is not a process-kill, emulator or live-server test.
- One new test initially compared an unchecked fixture descriptor with the parser's checksummed persisted descriptor. Its assertion now compares the published package with the canonical persisted package; existing expectations were not weakened.
- The first full run hit the default 30-second timeout in the new multi-publication lifecycle test, which had passed in the focused run. That run was interrupted after the failure rather than reported as passing. The encrypted-publication test file now declares a bounded two-minute timeout for its real crypto work under parallel-suite contention; all content/revision assertions remain unchanged. Its four scenarios passed in 31 seconds total on the follow-up run. A fresh complete workspace run uses /tmp/bbm-i3-unit-tests-final.log.
- Review used the Kumulynja checklist solo, with current repository architecture taking precedence over the skill's older conventions. It kept the change on the existing recorder/runner path and caught a transitive `collection` import; that import was removed in favor of direct value comparison, not made a new dependency.
- The graph now documents the already-existing WalletBackup → BullVault edge. The historical RecoverBull → WalletBackup → BullVault → RecoverBull cycle and old facade read methods that bypass use cases remain the separately planned I5 composition/refactor work. This change does not add a reverse BullVault → WalletBackup import or claim the entire graph is acyclic.
- Final full-suite log: /tmp/bbm-i3-unit-tests-final.log. Other logs: /tmp/bbm-i3-before.log, /tmp/bbm-i3-storage-tests.log, /tmp/bbm-i3-focused-final.log, /tmp/bbm-i3-unit-tests.log (interrupted unsuccessful first run), /tmp/bbm-i3-static.log, /tmp/bbm-i3-fix-check.log and /tmp/bbm-i3-format-check.log.
- The requested thorough follow-up review is recorded in [integration-i3-review.md](integration-i3-review.md). It applied the seven Bull Bitcoin review lenses and security checks solo, in accordance with the user's no-subagent instruction. No additional I3 blocker was found; existing signing/privacy/composition findings and untested device paths remain explicit. This is a scoped implementation review, not the final two-way stack-fidelity audit or an independent security audit.

## I4 continuation — revoke signing work when its private session ends

Scope: the retained Payjoin callback and awaited Bitcoin/Payjoin signing paths identified by the I3 review. Work remains on the same isolated integration branch, with no backend, protocol, schema, settings, or UI changes.

Implementation commit: `385e59c6a` (`fix(wallet): revoke signing work when the private session ends`). Normal pre-commit analysis, fix dry-run, and formatting passed without bypassing hooks. No push or deployment.

Three tests reproduced the old behavior before implementation: a retained processor still returned a signature after lock, still returned it after lock/re-unlock of the same wallet, and escaped successfully when lock occurred during processor creation. These tests used the real adapter and a counted fake native callback. A subsequent regression uses real BDK signing: the callback finalizes a synthetic PSBT while unlocked, then refuses that same signable PSBT after lock/re-unlock. No persistent seed-store interactions occur for these private-wallet tests.

### Implementation and simplification decisions

- The existing `WalletUnlockSession` owns a signing generation that changes whenever its loaded seed is cleared or replaced. Its guard captures the generation and wallet ID, not a copy of the seed. It rejects an ended unlock session permanently, including when the same wallet is opened again.
- This generation is separate from the existing mount generation: starting/cancelling an asynchronous mount and replacing a loaded signing session are different events. Replacing a seed under the same accepted mount generation must still revoke the old signer. No token registry, extra stream, subscription, manager, or lease class was added.
- The existing resolver supplies the guard only for `defaultSeedPassphrase` wallets; persistent signers retain their existing behavior. Callers capture permission after resolving public wallet metadata and before resolving private material. This is a signing-capability boundary, not a global cancellation mechanism for every earlier UI or metadata operation.
- Bitcoin signing rechecks after awaited preparation/material resolution and immediately before its synchronous descriptor-signing call. The existing exception mapper returns `walletLocked`. Ben's per-key selection, full derived-xpub comparison, protected-key handling, PSBT checks, sighash restrictions, and finalization behavior are unchanged.
- Payjoin carries the guard with its private wallet model, checks after asynchronous processor construction and on every returned callback invocation, and supplies the guard to ordinary datasource signing. That datasource checks before parsing and after native wallet creation, inside the existing disposal boundary.
- The follow-up review found another window in fee bumping: the old code could prepare a replacement in one session and then enter signing in a newly opened session. Fee bumping now carries its original guard across replacement preparation and the subsequent metadata read in `_signPsbt`. Unsigned replacement preparation now needs only the public wallet, not a mnemonic-bearing model.

### Review and adversarial checks

Review is solo, using the Kumulynja checklist with the current repository architecture as the source of truth, and checking architecture, evidence, async correctness, UX, simplification, scope, repository rules, and security. No multi-agent or independent security review is claimed.

- A simple `isUnlocked(walletId)` recheck is insufficient: reopening the same wallet would reactivate an old callback. The generation guard and regression tests cover that case.
- Checking only before an await is insufficient. Real BDK preparation is interrupted through the test path-provider boundary; the post-await check rejects signing, and the same PSBT signs successfully without the revoked guard. The test does not use a malformed PSBT to obtain a false-positive failure.
- Checking only after unsigned fee-bump preparation is insufficient: signing fetches metadata again. Separate tests lock/re-unlock during preparation and during that later fetch. Both must throw before a signature is produced.
- The new callback does not expose a datasource, native object, or seed through a feature facade. It uses the existing wallet/Payjoin port contract. No new cross-feature edge or dependency was added, so `FEATURES.md` is unchanged.
- Existing wallet business logic under `lib/core/wallet` and the concrete repository's `data/repositories` location predate this fix and do not match the current infrastructure-only core/directory conventions. A separate wallet-boundary extraction can address that legacy layout; moving signing ownership across features is deliberately not bundled with this security correction.
- Tests for regular persistent signing, multiple local signers, mixed/repeated/originless descriptor keys, protected keys, Taproot policy paths, and hostile PSBTs retain their existing assertions. Only mock argument matching was extended for the new guard parameter; it does not relax account, network, passphrase, finalized-input, or signed-content expectations.
- The current private-wallet creation path explicitly selects Bitcoin (`prepare_passphrase_wallet_usecase.dart`, `isLiquid: false`). This change does not invent Liquid passphrase-wallet support. Liquid's existing ordinary signing path is unchanged; a claim that all Liquid signing now uses this guard would be false.
- The only `EnsureCanonicalSeedUsecase` production consumer found is BullVault restore. Its candidate seeds come from the default/stored-seed use cases, not the private session, and `ensureCanonicalSeed` removes a mnemonic passphrase from the persisted canonical representation. That source trace does not replace the remaining restore/ownership integration audit.
- The guard authorizes an operation; it cannot retract signatures already produced before lock. It does not promise zeroization of Dart strings or immediate destruction of the native wallet captured by an old callback. An old callback is unusable after revocation, but comprehensive native-handle lifetime work remains distinct from this tested authorization fix.
- Existing secret-type concerns are not silently marked fixed: `SeedModel` has a redacted `toString` but still generated value equality/hash, unlike the identity-based signing material. The broader I4 secret-type audit must decide and verify that boundary without adding a parallel secret-type hierarchy.

### Verification

- Red reproduction: three failures in `/tmp/bbm-i4-red.log`, before the implementation.
- Initial targeted suite: 91 passed in `/tmp/bbm-i4-focused.log`.
- Expanded targeted run: 102 passed in `/tmp/bbm-i4-focused-final.log`; the final two-window fee-bump suite separately passed all 12 tests in `/tmp/bbm-i4-rbf-final.log`.
- Existing native fee-bump and use-case suites: 10 passed in `/tmp/bbm-i4-rbf-native.log`, including a real finalized replacement transaction after switching unsigned preparation to the public wallet model.
- Whole-project analysis and bull_ui boundary pass in `/tmp/bbm-i4-analyze-final.log`. Fix dry-run and tracked-source formatting are checked through the makefile and normal commit hook.
- The first full run was deliberately interrupted after the review found the fee-bump window; it is not a completed verification result. The complete rerun covering the final source, `/tmp/bbm-i4-unit-tests-final.log`, exited 0: 3,212 root tests plus all seven package suites (bull_logger 7, bull_payjoin 77, bull_tor 27, bull_ui 40, bull_ui_catalogue 1, primitives 17, screen_privacy 10). Total: 3,391 passed, zero failed; 11 new regression tests compared with the I3 baseline.
- These are offline host tests with synthetic transaction data. No broadcast, external publication, emulator installation, or hardware signing was performed. Native host signing is not a substitute for the remaining app-background/device and real Payjoin protocol checks.

### Scoped review verdict

Approve this private-signing revocation substep for continued integration. The review found one additional important defect, the fee-bump session switch described above; it was fixed and retested before the final full run. No further blocker was found in this change. This is a solo implementation review, not independent security approval, completion of all I4 work, or approval of the entire branch.

Next: continue canonical ownership/secret-type checks and I5 restore/privacy/composition work. The branch is not release-ready and the distributed-recovery implementation remains pending.

## I5c continuation — protect BullVault passphrase input before rendering

Implementation commit: `06a7034bb`. The mobile-passphrase onboarding step and
BullVault restoration screen now reuse the existing `PrivacyGate` with the
stored enable future. Pending, rejected, null and failed native responses cannot
render their passphrase fields. Those inputs also exclude secret content from
semantics. This closes the concrete onboarding finding recorded above; it does
not change the existing user preference that can opt out of capture protection.

Two tests failed against the previous implementation because the fields were
visible while protection was still pending. The new twelve-case widget suite
covers both screens, positive/refused/null/error responses, leaving while enable
is pending, subsequent retry and overlapping protected references. It uses real
Cubits and verifies successful passphrase entry and confirmation. The existing
restore scan regression retains its descriptor assertion and now supplies a
positive mocked native response before interacting with the screen.

Verification: 29 BullVault UI tests passed in
`/tmp/bbm-i5-privacy-tests-final.log`; after adding the final typing assertion,
the twelve new cases passed again in `/tmp/bbm-i5-privacy-entry.log`.
Whole-project analysis and normal pre-commit checks passed. The initial
post-fix test run had a newly introduced channel-mock future-encoding error;
that test harness was corrected, not the positive-response requirement.

Solo source/caller review found no additional blocker in this narrow change.
It adds no privacy service, state manager, dependency or copy changes. On-device
capture/background verification remains pending, and this is not completion of
the entire I5 privacy/device gate.

## I4 continuation — seed diagnostics and canonical-owner checks

Implementation commit: `5ee62f823`; normal pre-commit checks passed.

The generated `SeedModel` now uses identity equality/hash, like the existing
seed/signing entities; its storage JSON and redacted `toString` are unchanged.
Malformed seed JSON previously leaked through retry logging, and raw storage
exceptions also reached repository logs and the two Result-based seed failure
messages. These sites now record only exception types, with sanitized typed
failures. Five new tests failed before the fix, including a real malformed
storage read through all five retries. Logging tests require the operation log
to exist as well as requiring the synthetic secret marker to be absent.

Three more tests exercise Ben's existing canonical owner: it stores the
passphrase-free parent, does not rewrite a matching stored seed, and rejects a
different seed under the same fingerprint using full byte comparison. No seed
derivation, serialization, persistence ownership or signing rule was changed.
An existing protected-key signing fixture depended on generated whole-model
equality; its mock now explicitly matches the exact words and null passphrase,
stores the actual supplied model, and retains all original missing/wrong/correct
passphrase and signed-fingerprint assertions.

Verification: code generation completed; whole-project analysis passed in
`/tmp/bbm-i4-seed-analyze.log`; all 169 focused seed, native Bitcoin signing,
BullVault restore, private-wallet and session-boundary tests passed in
`/tmp/bbm-i4-seed-tests-final.log`. The first targeted run failed only on that
seed-equality-dependent fixture; it is not a passing result. Red reproduction
is `/tmp/bbm-i4-seed-red.log`.

Solo review kept the existing model and storage contracts instead of adding a
parallel secret hierarchy. This is a scoped leak correction, not a statement
that all exceptions are secret-safe: the existing throwing repository APIs
still rethrow failures, so downstream caller diagnostics remain part of the
broader audit. No Dart-string zeroization, native memory erasure or device
privacy guarantee is asserted. Full-workspace verification follows the next
coherent integration checkpoint.

## I5a continuation — descriptor-to-seed wallet upgrades

Implementation commit: `ad1231246`; normal pre-commit checks passed.

Ben's script-identity deduplication can upgrade a descriptor-imported wallet
without changing its hashed ID. The old copy retained descriptor provenance and
the previous passphrase fact despite replacing the signer with a verified local
seed. Four real-SQLite tests reproduced that stale provenance for default and
imported wallets, with and without a passphrase. A fifth test reproduced the
backup inventory throwing when it tried to decode the hashed ID as a seed path.

The upgrade now copies the derived provenance and passphrase fact together with
the signer. Recovery inventory reads the normalized signer's account path and
the descriptor's script type instead of decoding the retained ID. The existing
ID, nondefault label, earlier birthday and script-identity deduplication are
preserved. The tests check persisted state, inventory, removal from the generic
definitions contribution, local-key inventory and recovery-identity matching.

All 34 focused wallet-definition, descriptor-import and manifest-restore tests
passed (`/tmp/bbm-i5-upgrade-tests.log`); five pre-fix failures are recorded in
`/tmp/bbm-i5-upgrade-red-actual.log`. The earlier test-selection attempt matched
no tests and is not red evidence. No schema change or new service was needed.

Solo review: this fixes the upgraded wallet's current recovery facts. It does
not prove a fresh seed restore can reconcile a previously hashed default-wallet
reference with its newly created seed-origin reference; that remaining I5a
cross-installation case needs an end-to-end test before claiming complete
metadata recovery. Per-key BullVault ownership, restore lineage/visibility,
physical-onboarding context and dependency-cycle work remain separate gates.

## I5a continuation — preserve signer facts in wallet definitions

The definitions codec dropped Ben's `registrationName`, `localSeedFingerprint`
and per-key `requiresPassphrase`. Three pre-fix diagnostic tests reproduced the
loss. A protected descriptor wallet could therefore lose its canonical seed
lookup and passphrase prompt on recovery; hardware registration names were also
absent. Definitions now write version 3 with all three facts. The envelope and
other sections retain their versions; strict version-2 reading remains for saved
files, with absent facts left unknown rather than invented. Version 1 remains
rejected under the existing decision, and newer versions retain the recovery
fence. This is not a database migration.

The archived full version-2 golden is unchanged. A separate current golden
includes the new null/false fields and definition version, with all other bytes
preserved. Tests verify reading the archived document and canonical current
output, exact current bytes, malformed facts and future-version rejection. An
existing empty-definitions test had actually failed on its obsolete section
version; it now uses the valid section version to exercise the empty-list rule.
The first new golden accidentally normalized an unrelated `3.0` JSON number to
`3`; the failing exact-byte assertions caught this and the fixture was corrected.

The original native protected-key test still runs unchanged in behavior, plus a
second case that round-trips its real signer through the codec before signing.
Both require the exact missing/wrong/correct passphrase outcomes and actual
signed key fingerprint. A real SQLite restore test verifies all signer fields
and the re-exported payload after deleting the original wallet.

The registration-name mutator also failed to dirty the backup. Its new
regression failed before correction. It now shares the existing transactional
signer-update path with device changes: one committed revision/wakeup for a real
change, none for an identical write or nonexistent signer. An injected revision
failure proves the registration write rolls back and emits no event.

Implementation commit: `e15e1d047`. Verification: 92 focused codec, SQLite and native-signing tests passed
(`/tmp/bbm-i5-roster-roundtrip-complete.log`), followed by all 16 codec tests
after adding symmetric writer validation
(`/tmp/bbm-i5-roster-writer-validation.log`). Whole-project analysis and normal
commit hooks passed. All 304 WalletBackup/BackupSettings tests also passed
(`/tmp/bbm-i5-backup-feature-gate.log`, concurrency 2), including the previously
timed-out durability case with its unchanged timeout. The synthetic
multi-signer serialization fixture alone is not proof of key ownership; the
native test supplies the real-key signing check. Existing annotation validation
and BullVault-local ownership are still reviewed separately.

## Verification checkpoint — interrupted full suite is not a pass

The full `make unit-test` attempt at `ad1231246` timed out in the existing
`a change during a publication leaves one more pass to run` test after its
30-second limit. The root run was subsequently interrupted. Flutter exited zero
after the interrupt, so make continued its package suites; that exit status is
not a successful full-workspace result. Evidence:
`/tmp/bbm-i5-core-unit-tests.log`. The same durability test passed in isolation
in ten seconds (`/tmp/bbm-i5-durability-isolated.log`), without changing its
assertions or timeout. A complete clean run is still required.

A new disposable Android AVD, `bullvault_integration_v2_20260909`, is booted on
`emulator-5584`. The existing `bip138_prototype` on `emulator-5582` is untouched.
No app build/install or device recovery result is claimed yet; Android native
builds wait for host native tests to finish.

## I5a continuation — re-verify existing BullVault ownership

Implementation commit: `298818399`; normal pre-commit checks passed.

Six tests reproduced already-local signers retaining a missing/wrong canonical
seed reference or wrong passphrase flags on repeated descriptor recovery, both
with and without a delayed mobile recovery key. The ownership check previously
examined only xpub and `local` classification, and its repair helper returned
early for any local signer. The check now also compares the verified canonical
seed reference and each key's passphrase requirement; repair no longer skips
incomplete local signers. Full seed/xpub verification still precedes this work,
and the returned ownership update is checked before recovery reports success.

A seventh test reproduced a persisted record defaulting to the protected
everyday fingerprint rather than the canonical parent. Repeated restoration now
repairs the saved record and account reservation from the verified key facts,
even if its mobile account was already set. The descriptor, policy dates,
lineage, external signer assignments and existing wallet identity stay intact.
The compatible-wallet test fixture now explicitly supplies its canonical local
seed reference; no existing expectation was weakened. Seven new two-restore
crypto tests have a bounded two-minute timeout, not a changed assertion.

Verification: the six signer cases failed before the fix in
`/tmp/bbm-i5-existing-owner-red.log`; the saved-record case failed in
`/tmp/bbm-i5-record-owner-red.log`. Final restoration and backup integration
tests passed 40/40 in `/tmp/bbm-i5-ownership-verified-tests.log`.
Whole-project analysis is clean in
`/tmp/bbm-i5-existing-owner-analyze-final.log` after removing two redundant
non-null assertions. A separate attempted test command named a nonexistent
backup test file; it failed to load that file and was interrupted, and is not
counted as a passing verification (`/tmp/bbm-i5-existing-owner-final-tests.log`).

Solo review kept Ben's canonical owner and existing ownership port, without
introducing another seed store or signing path. These tests do not substitute
for hardware verification or close the remaining adversarial signer-annotation,
fresh-ID remapping and on-device recovery gates.

## I5 recovery continuation — fresh Encrypted Vault restoration

Implementation commit: `7ef751407`; normal pre-commit checks passed.

Source/caller review found the recovery BLoC invoked the existing-wallet backup
verification helper before restoring the seed. That helper rejects a mnemonic
when no matching wallet exists, so a fresh installation could never reach the
actual restore operation. Two flow tests reproduced the failure, with optional
metadata recovery both complete and incomplete.

The restore branch now calls `RestoreVaultUsecase` directly after decryption.
That use case already creates the wallets and records their encrypted-backup
timestamps. The verification helper remains unchanged for testing an existing
backup or viewing its key. No decryption validation or seed-restoration failure
was bypassed. New tests verify seed failure never starts metadata recovery or
wallet synchronization, and four test/view cases retain the existing matching
wallet requirement. This is a concrete recovery fix, not the separate planned
dependency-cycle refactor.

Verification: two pre-fix failures in `/tmp/bbm-i5-fresh-seed-recovery-red.log`;
all 86 feature/core RecoverBull tests passed in
`/tmp/bbm-i5-fresh-seed-recovery-final-tests.log`. The flow tests exercise the
real BLoC with port results; they do not claim a live RecoverBull-server or
emulator recovery proof.

## I5d — app-composed seed-recovery completion

RecoverBull no longer imports WalletBackup. The app router supplies one
completion callback with the existing wallet-ID context, and an app-level
function calls the owning WalletBackup facade. The feature-local forwarding
use case is removed, its tests move with the composition function, and
`FEATURES.md` no longer claims the removed edge. This breaks the targeted
BullVault → RecoverBull → WalletBackup → BullVault dependency path without a
new manager, event bus, service registration or secret-bearing public input.
It does not claim every legacy dependency cycle has been removed.

Review reproduced two additional failures at this boundary. An exception from
optional metadata recovery escaped and could report already successful seed
recovery as a decryption failure. The app-level completion now reports incomplete
metadata and logs only the exception type. Existing typed statuses retain their
meaning: only `restored` and `noBackup` count as complete. Separately, closing
the flow while seed restoration or metadata follow-up was pending still
dispatched later follow-up/synchronization. The BLoC now guards those awaited
boundaries and does not emit completion into a closed flow. It does not attempt
to undo seed persistence or recall an already-dispatched metadata operation.

One pre-fix exception test failed in `/tmp/bbm-i5-optional-completion-red.log`;
two pre-fix closing tests failed in
`/tmp/bbm-i5-completion-cancellation-red.log`. All 97 completion and feature/core
RecoverBull tests passed in `/tmp/bbm-i5-completion-tests.log`, including every
metadata status, exact ID forwarding, cancellation, seed failure and existing
backup verification. All 24 startup/legacy-backup-route/backup-route tests passed
in `/tmp/bbm-i5-completion-startup-tests.log`. Whole-project analysis is clean
(`/tmp/bbm-i5-completion-analyze.log`). Commit `ac6bdf0d3` passed normal
commit hooks (`/tmp/bbm-i5-completion-commit.log`).

Solo source/caller review confirms the old feature-local use case and
RecoverBull-to-WalletBackup imports are absent. Physical onboarding and the
distinction between actually created and previously existing wallet IDs remain
I5b work; this refactor deliberately preserves the existing context contract.
Actual app initialization and recovery on the disposable emulator remain I8
checks rather than claims inferred from these host tests.

## I5b — physical recovery context and backup-status cancellation

Physical onboarding discarded the default-wallet creation result. Home-page
Data Backup then recovered without the IDs of newly created defaults and treated
their backed-up preferences as conflicts. The creation result now distinguishes
returned wallets from new identities using the stored inventory (including
hidden wallets); existing defaults and adopted descriptor-wallet IDs are excluded.
Rollback also excludes identities present before creation. Encrypted Vault
recovery uses that same distinction instead of classifying every returned default
as newly created. Seed-creation and onboarding failures no longer interpolate raw
foreign exceptions into messages or log fields.

Physical onboarding forwards the new IDs through its result/state and the home
navigation payload to the existing banner → wizard → Data Backup enable/recover
path. Home navigation still precedes network access. This adds no coordinator,
durable recovery-context table, event bus or cross-feature dependency. The route
payload is consumed once when the banner starts, including across remounts, and
manual retries carry no stale permission to overwrite later local preferences.
Existing local conflicts remain incomplete recovery and block publication.

The combined test uses real onboarding orchestration, wizard application,
metadata classification, backup facade/runner, SQLite backup state, codecs and
encryption. Seed creation, preference storage, the remote transport and unrelated
section owners are controlled boundaries. It verifies nonblocking home handoff,
fresh-wallet preference restoration, preservation of a pre-existing label,
enablement on success, and no replacement publication on conflict. Separate
core tests cover fresh/adopted/existing default-ID classification and the real
SQLite repository's inclusion of a locked, invisible wallet in the inventory.
This is not an emulator seed restore or real-server recovery claim.

The combined test also exposed a pre-existing lifecycle bug: cancelling an idle
backup-state subscription waited for another database event. A standalone
repository test reproduced it in `/tmp/bbm-i5-idle-watch-red.log`; the two combined
tests timed out specifically at banner cleanup in
`/tmp/bbm-i5-physical-continuity-diagnostic.log`. Replacing the `await for` forwarding
loop with `yield*` lets cancellation reach the underlying Drift stream. No timer,
polling, unawaited cleanup or timeout increase was used to hide the defect. The
banner also guards duplicate starts and the interval while close is in progress.

Verification so far: 118 core/onboarding/RecoverBull tests passed before the UI
handoff change (`/tmp/bbm-i5-created-context-final-tests.log`); 38 combined-flow,
wizard, banner, enablement and storage tests passed after the cancellation fix
(`/tmp/bbm-i5-physical-continuity-verified-tests.log`). Whole-project analysis passed
(`/tmp/bbm-i5-continuity-cancellation-analyze.log`). The final expanded focused run
passed all 46 tests (`/tmp/bbm-i5-continuity-close-final-tests.log`), including the
closing-while-subscription-cancels guard. Commit `1fa60514f` passed normal hooks
(`/tmp/bbm-i5-physical-continuity-commit.log`); the full-workspace rerun remains
pending.

This remains a scoped integration adaptation. It does not fix the separately
identified historical hashed-reference remapping, claim concurrency isolation for
unrelated wallet imports during onboarding, or change Ben's existing default-wallet
adoption label behavior. User edits occurring while initial remote recovery is
in flight need a separate adversarial check; the existing preference CAS guards
the classified-to-write interval, not every earlier network await. Offline retry
conflict resolution and actual navigation/device lifecycle remain I8 checks.

## I4 continuation — decrypted recovery models and failure diagnostics

Two synthetic tests reproduced generated diagnostic strings containing the
decrypted mnemonic, backup password and vault key
(`/tmp/bbm-i4-recovery-secret-models-red.log`). `DecryptedVault` and
`RecoverBullState` now use redacted diagnostics and identity equality/hash, matching
the already-adopted private signing model convention. Copying and intentional
JSON serialization still preserve recovery data. A guarded-list test throws if
diagnostics, hashing or equality attempt to read any mnemonic word; nonsecret
flow/loading/completion facts remain visible in the recovery-state diagnostic.

A separate real-BLoC test reproduced a foreign creation exception copied into a
failure's `logMessage` (`/tmp/bbm-i4-recovery-exception-red.log`). The three raw
exception logging catches in RecoverBull now record only the exception type, and
the two unexpected-failure wrappers no longer interpolate the raw message. Typed
decryption failures are unchanged. The log-file test has a positive control that
requires the exception type to appear; checking an empty/unconnected capture for
absence of a secret is not accepted as evidence. Its logger is explicitly attached
and the previous directory restored for subsequent tests.

All 103 feature/core RecoverBull and app-completion tests passed in
`/tmp/bbm-i4-recovery-secrets-final-tests.log`, and whole-project analysis passed
in `/tmp/bbm-i4-recovery-secrets-analyze.log`. All 27 BLoC/model tests passed with
the strengthened positive-control log capture in
`/tmp/bbm-i4-recovery-secrets-capture-tests.log`. Two additional validation tests
reproduced raw private input retained in `ArgumentError.invalidValue`
(`/tmp/bbm-i4-backup-inputs-red.log`); backup encryption-key and ciphertext
constructors now reject invalid input without echoing it. Valid normalization
and encoding are unchanged. All 34 combined follow-up tests passed in
`/tmp/bbm-i4-recovery-encryption-final-tests.log`. Commit `b502461fc` passed normal
hooks (`/tmp/bbm-i4-recovery-secrets-commit.log`). The full `make unit-test` run at
that commit is in progress (`/tmp/bbm-i5-complete-workspace-tests.log`).
This does not claim memory
zeroization, remove intentional seed serialization, or establish that every
legacy external-service exception path in the repository has been audited.

## I8 in progress — core fidelity checkpoint at b502461fc

The replay range-diff is retained at `/tmp/bbm-i8-core-range-diff.log`: 19 patches
are identical, 12 are adapted, and the share-sheet-was-shown-as-export-success
patch is deliberately excluded. The latter is not an accidental dropped hunk:
showing a share sheet does not establish the approved descriptor handoff.

A structural comparison of Ben's pinned v16 JSON against current v17 JSON
preserves all 34 upstream tables/indexes, every original column definition,
constraint and resolved table/index reference. Only generated entity numbers
were normalized. Additions are `hide_on_home`, `auto_sweep_enabled`, `provenance`
and `seed_passphrase_used` on wallet metadata, plus the three keychain-manifest
tables and `wallet_backup_states`. This confirms schema preservation, not the
still-pending final published-schema consolidation or all migration paths.

The full host suite passed at `b502461fc`: 3,292 application tests plus 179 tests
in all seven packages, 3,471 total, with exit code zero and no interruption
(`/tmp/bbm-i5-complete-workspace-tests.log`). Application/test source was held
unchanged during that run. The owned emulator is confirmed booted as
`bullvault_integration_v2_20260909` on `emulator-5584`; no Android build overlaps
native host tests. Device recovery, signing and the full two-way source review
are not marked complete by this checkpoint. The generated integration aggregator
is now running on that emulator (`/tmp/bbm-i8-emulator-integration.log`), with
funded-test mnemonic/enablement defines unset. No production backup publication
is authorized by this device check.

### Environment restart and evidence retention

On 2026-09-10 the execution environment restarted before the device build produced a result. The prior process handle no longer existed, no integration-test process was running, its `/tmp` log was gone, and no APK existed at the expected output path. That interrupted attempt is not a successful device check. Source remained at `b502461fc`, with only this execution record uncommitted.

The historical host-test and review results above were observed before the restart; their `/tmp` paths are historical references, not a claim those temporary files are still available. The owned AVD `bullvault_integration_v2_20260909` was restarted on port 5584 and its boot completion verified. The pinned Flutter 3.44.9/Dart 3.12.2 SDK and generated localization files remain present. A fresh integration-aggregator run is in progress, with its log outside `/tmp` at `/home/francis/bbm-i8-device-tests.log`. Application source remains unchanged for this run; funded-test environment defines remain unset.

### Backend baseline and local emulator service

The unchanged backend at `8cea0b52b2c397a4fd2558b26e93338693be083a` passed `cargo test --locked` (38 unit tests and two startup tests), formatting, and `cargo clippy --all-targets --locked -- -D warnings`. `cargo audit` fetched the current RustSec advisory database and reported no vulnerabilities among the 103 locked dependencies; this is dependency-advisory coverage, not a completed protocol/security review. Logs are `/home/francis/bbm-backend-baseline-tests.log`, `/home/francis/bbm-backend-baseline-clippy.log`, and `/home/francis/bbm-backend-baseline-audit.log`. Its worktree is unchanged.

A disposable instance uses `/home/francis/bbm-i8-server.csZ9fZ/backup.sqlite3` and loopback port 8234. A scratch, loopback-only test proxy on 8235 supplies the backend's required `X-Real-IP` header; it is not production deployment code or an application change. The owned emulator forwards its localhost port 8235 with `adb reverse`. Health returned 204 and a malformed fetch returned the expected sanitized invalid-request response. No authenticated backup publication or emulator recovery is claimed from those checks. The normal emulator app must explicitly use this local origin before any backup write; production service writes remain out of scope.

### Device integration result at b502461fc

The fresh build completed in 909.6 seconds, installed its test-entrypoint APK, and initialized the actual Android database and secure storage. The aggregator finished with 20 passing tests, ten skipped tests and one failing test, exit code one. Embedded Tor became ready, but the existing RecoverBull fixture's server fetch failed with `hostUnreachable`. Its required successful-fetch assertion remains intact. This is not a green full-device gate or proof of live server restoration. The four local legacy/current key derivation and decryption checks passed. Teardown also tried the unsuffixed `com.bullbitcoin.mobile` package and reported an uninstall error; the test APK uses `com.bullbitcoin.mobile.debug`. A normal application APK still needs to be built before manual navigation. Evidence: `/home/francis/bbm-i8-device-tests.log`.

## I4/I8 — reject malformed descriptors without leaking private input

Four new tests reproduced an xprv/tprv in a malformed Miniscript fragment being quoted in `MiniscriptDescriptorException`, including through `restoreWalletDefinition` before any persistence. Valid private descriptors were already rejected, but that did not protect malformed input. A shared private helper now checks public-only content and sanity while sanitizing native descriptor failures. The fieldless checksum exception remains unchanged; all receiving/change parsing and normalization still happen through Ben's parser, and failed native handles are disposed. No alternate parser, private-input regex, new dependency or new importer was introduced.

The native single-key-private and wrong-network rejection tests now expect a sanitized `FormatException`, rather than the foreign `DescriptorException`; they still require rejection of exactly the same inputs. Checksum, fixed-key, Miniscript, Taproot and signing assertions are unchanged. New tests cover five private-input shapes on both networks, the separately parsed change descriptor, rejection without SQLite writes, and equivalent origin/checksum/receive-change notation without false restore conflicts.

The pre-fix run failed four cases (`/home/francis/bbm-i8-descriptor-privacy-red.log`). All 165 focused native datasource, descriptor restoration and watch-only import tests passed after the fix (`/home/francis/bbm-i8-descriptor-privacy-fixed.log`). Commit `09bdd6b49` passed normal hooks, including whole-project analysis, Dart fix and formatting (`/home/francis/bbm-i8-descriptor-privacy-commit.log`). The completed device run above still represents the earlier application source, not this fix. Full-workspace revalidation and a normal rebuilt APK remain required. Solo review checked resource disposal, parser callers, exception-type consumers and the unchanged upstream validation assertions; no independent security approval is claimed.

The complete `make unit-test` rerun at `09bdd6b49` subsequently passed with exit zero: 3,307 application tests and 179 tests across all seven packages, 3,486 total (`/home/francis/bbm-i8-complete-workspace-tests.log`). Application and host-test source remained unchanged during that run. The new Android-only local recovery test is not part of that count. It is opt-in and requires an empty wallet inventory and absent fixture seed; it never clears app data itself. The only installed BULL package on the owned AVD was confirmed as `com.bullbitcoin.mobile.debug`, then its synthetic test data was cleared with `pm clear` before the separate local recovery run. All source fixtures remain available to recreate that data.

## I5/I8 — reject unrelated Encrypted Vault seeds on initialized apps

The opt-in local Android recovery test reproduced a false success at `09bdd6b49`: fresh seed restoration and a repeat restoration succeeded with real SQLite and Android secure storage, but an unrelated public fixture seed also returned `Ok`. The default-wallet creation helper reuses existing defaults, so removing the old existing-wallet-only verification gate to support fresh installations had also removed its mismatch protection. Evidence: `/home/francis/bbm-i8-local-recovery-red.log`; the required `Err` assertion failed after the fresh/repeat checks passed. This is a distinct local correctness issue from the external RecoverBull fixture's unreachable server.

`RestoreVaultUsecase` now verifies every existing default wallet in the selected environment against the supplied seed's complete derived account public key before calling default-wallet creation or updating backup timestamps. It reuses the existing BIP32 matcher and settings repository contract. An empty inventory still permits fresh restoration; missing key/path, a different seed, and a passphrase-derived mismatch are rejected. The test fingerprints deliberately remain identical across different full keys so a fingerprint-only check would fail the regressions. No new key store, recovery manager, migration or cross-feature dependency was introduced.

All 16 focused use-case tests passed (`/home/francis/bbm-i8-restore-guard-tests.log`) and whole-project analysis passed (`/home/francis/bbm-i8-restore-guard-analyze.log`). The new cases cover both environments, Liquid's account path, testnet public-key serialization, partial/mixed defaults, and rejection before creation or timestamp writes. The existing device server test also now expects only newly created IDs from a repeated restore; it retains its server-fetch and actual-seed checks. The full workspace rerun and fixed Android rerun are still pending at this entry.

### Continued solo fidelity checks

Regenerated the replay range-diff outside temporary storage at `/home/francis/bbm-i8-core-range-diff.log`. The 19 identical patches include the codec, job runner, definitions, file recovery, atomic metadata revision, lost-response acknowledgement and conflict-fence changes. The old schema-alignment commit appears as an unmatched removal/addition in Git's heuristic matching, but its manually mapped replacement is `58cffe94b`; it is not a second omitted donor. Its remaining behavioral work is Result-API adaptation, with schema generation already absorbed earlier. The share-sheet-success patch remains the only deliberately excluded donor.

Reviewed non-generated patch deltas for the remaining replay slices against their donor patches: primary-fingerprint reads on mnemonic screens follow Ben's single-local-seed ownership API; the extracted inheritance screen retains the privacy gate; BullVault record enumeration uses Ben's SQLite transaction owner; the obsolete visibility callback and corresponding call-count assertion were removed because visibility is now committed in the upstream lifecycle transaction. Subsequent real-storage tests, not that removed mock callback, cover the lifecycle integration. The recovery verification adaptation that incorrectly required every wallet to match was already corrected in `ad17f4805` and remains recorded above.

The Bitcoin repository tests retain upstream expectations and instantiate the real signing-material resolver around a mocked seed datasource. The private-session boundary test calls production `signPsbt` after locking and expects typed `walletLocked`, with no persistent seed reads. Real native signing is separately exercised in `test/core_test/wallet/data/repositories/bitcoin_wallet_repository_test.dart`, including volatile-session signing and protected per-key signing after backup codec restoration. Payjoin callback tests assert a signature before revocation, then rejection without a second signature after lock/reopen. Settings search expectation changes match actual root entries and navigation: Wallet Recovery, Data Backup, Nostr keys and passphrase wallets; the legacy backup path redirects to Wallet Recovery. These checks do not close the outstanding device, cross-installation reference-reconciliation or full reverse-source audit gates.

### Fixed local recovery verification

The complete workspace rerun passed: 3,321 application tests plus all 179 package tests, 3,500 total, exit zero (`/home/francis/bbm-i8-restore-guard-workspace.log`). Commit `ae42b04f9` passed the normal analysis, Dart fix and formatting hooks (`/home/francis/bbm-i8-restore-guard-commit.log`). The same Android test that reproduced the false success then passed after a fresh 75.2-second APK build and install: new restoration, repeated restoration, unrelated-seed rejection, unchanged inventory/backup timestamps and absent unrelated seed storage all checked (`/home/francis/bbm-i8-local-recovery-fixed.log`). This bypasses the external key-server fetch by supplying a decrypted public fixture; it is not a claim that the unreachable live RecoverBull fixture now works.

A separate opt-in two-install local metadata test is being prepared. Its publication and recovery phases require a fresh app database and the explicit loopback server origin before app initialization. Only the disposable local backend database is retained between phases. The intended assertions include the complete inheritance-enabled vault descriptor, wallet labels, a transaction label, remote inventory and a cleared recovery fence. No result is claimed until both phases have run.

The first publication attempt built and ran on Android, but failed before upload: the real BullVault restore returned `Err` for the reused inheritance fixture (`/home/francis/bbm-i8-metadata-device-publish.log`). A diagnostic rerun adds explicit checks of package decoding, network, default-seed resolution and full mobile-key matching; it does not relax the required successful restore. The backend still had zero heads before this test, and no metadata round-trip success is claimed.

The physical-onboarding continuity harness now also edits the just-created wallet's label and visibility during the initial remote fetch. The new assertion failed: `Recovered savings` overwrote `Edited while recovering`, while the two original fresh/pre-existing preference cases passed (`/home/francis/bbm-i5-preference-inflight-red.log`). The one-use created-ID context currently permits this overwrite because the existing compare-and-swap only guards from classification to write, not from wallet creation through download. This regression is reproduced but not fixed at this checkpoint; the unchanged 3,500-test passing result above predates this newly added failing case.

The Android import failure was isolated to the shared test fixture: it hashed the uncanonicalized descriptor into the policy ID, unlike production creation, which canonicalizes before constructing the policy. Four new mainnet/testnet and inheritance/no-inheritance checks all failed before correcting that helper. Commit `21e807fa2` corrects the fixture, not production validation; no existing golden or expected value was changed. All 425 BullVault and wallet-backup tests then passed (`/home/francis/bbm-i8-vault-fixture-fixed.log`), and normal commit hooks passed. The next Android attempt successfully imported the vault but exposed a test wiring error: `UpdateWalletLabelUsecase` is constructed inside the registered `WalletFacade`, not individually registered. The opt-in device test now uses that facade and is being rerun. Neither failed attempt reached metadata publication.

The preference-race fix will replace the transient created-ID permission with each wallet's actual creation-time preferences. The existing conditional write can then reject edits made before or during the remote download as well as edits made between classification and write. The context remains one-use and nonpersistent; no new manager, storage schema or compatibility fallback for the unsafe permission is planned.

### Android publication and preference-race verification

The corrected local-server publication phase passed on Android (`/home/francis/bbm-i8-metadata-device-publish-facade.log`, 131.6-second APK build). It imported the inheritance-enabled vault through the actual BullVault facade, changed the Mobile wallet label through the Wallet facade, stored a transaction label, published encrypted metadata, and read back the full descriptor and inventory through the backup facade. The disposable backend now contains one head. This APK was compiled before the preference-context changes below; SHA-256 `635c2efe672b1b36dc1d8048170249ff9efc2a0540ffa5afac6ecc5a13f1a014`. Fresh-install recovery of that head is still to be run; publication/readback alone is not recovery evidence.

The preference fix now carries initial preferences rather than bare IDs through physical and Encrypted Vault recovery, the one-use home context, wizard consent, backup facade and fenced apply path. Default-wallet baselines come from the immutable wallets returned by creation, with adopted/pre-existing wallets excluded. Definition restoration starts with unset preferences; new BullVault restoration uses the imported wallet's label. The metadata provider compares all three preference fields against that baseline, then retains the existing database compare-and-swap for races during the final write. Equal existing/recovered values remain a guarded no-op. No schema, dependency, new manager or secret-bearing context was added.

All four physical-onboarding cases now pass: fresh recovery, pre-existing conflict, edit during fetch, and edit before fetch (`/home/francis/bbm-i5-preference-physical-fixed.log`). Each conflicting case preserves the local preferences, leaves the consent pending and does not replace the remote ciphertext. Six provider cases independently cover label, visibility and auto-sweep edits, both since creation and during the conditional write. The remaining focused tests passed (319); the initial focused run failed only because this newly edited physical test was missing its conditional-write result import, which was corrected before the four-case rerun. Whole-project analysis is clean (`/home/francis/bbm-i5-preference-analyze-clean.log`). The complete workspace rerun is in progress; no updated full-suite count is claimed yet.

Additional I5 investigation, not yet reproduced: Bitcoin testnet and Liquid testnet use the same seed/account derivation path, while a BIP32 manifest entry ID currently contains the fingerprints and path but no network. The inventory refresh includes both networks and the entry model allows only one wallet per BIP32 entry. A real inventory round-trip test must establish whether this collision loses or rejects one wallet before the core gate closes. This is separate from the already identified hashed-default-reference reconciliation issue.

The preference fix is committed as `e6d04c19e`; normal hooks passed. The complete workspace run finished successfully: 3,333 application tests and 179 package tests, 3,512 total (`/home/francis/bbm-i5-preference-workspace.log`). An explicit provider-only rerun also passed all ten tests, including all six new edit cases (`/home/francis/bbm-i5-preference-provider-fixed.log`). The two-install metadata test's recovery phase is now running on a fresh Android installation against the same retained loopback-server database. Two additional inventory regression cases, for mainnet and testnet defaults, have been prepared separately and are not included in the passing 3,512-test count.

Both Android metadata phases passed. The fresh recovery build took 81.3 seconds and the test completed successfully in 34 seconds (`/home/francis/bbm-i8-metadata-device-recover.log`; APK SHA-256 `d001c64aa8b6f1573e56070869a56cefa1892b7f9baf7ccbd1f1768eaf669e42`). Startup verified an empty secure store and app database; after restoring only the public-fixture Mobile mnemonic, server recovery reconstructed the inheritance-enabled BullVault, full descriptor, wallet labels and transaction label, and cleared the recovery fence. A subsequent publication and remote inventory read also succeeded. Neither phase used real funds or a production server. The APK still has a test entrypoint, not the normal application UI. Whole-repository formatting and the Bull UI import-boundary check also passed (`/home/francis/bbm-i5-preference-style.log`).

### I5 — network-qualified seed inventory identities

The new inventory test reproduced a SQLite primary-key conflict when Bitcoin testnet and Liquid testnet defaults were stored together; the corresponding mainnet case passed (`/home/francis/bbm-i5-network-inventory-red.log`). This prevented publication rather than silently omitting one wallet. BIP32 entry identities now include the wallet network, and the codec derives that identity from the already-recorded network. BIP85/Nostr identities are unchanged. Entry IDs are internal database keys, not fields in the manifest JSON; this does not add a wire field or change existing serialized fixtures. No schema table or column was added. Existing unreleased development databases with old manifest row IDs require a reset; no compatibility migration is being invented for those unshipped states.

The initial focused rerun passed 282 tests but found one missed test-fixture call to the identity builder in the Nostr allocation test. It now supplies the wallet's existing mainnet network without changing the allocation expectation. Whole-project analysis passed. A focused recheck is running before rebuilding the normal application entrypoint for manual emulator inspection; neither this identity change nor the new two-case inventory regression is yet included in an updated full-workspace passing claim. The verified standalone Android metadata test is committed as `56aa0573f`.

### I5 — reconcile descriptor-adopted default wallet references

A real SQLite regression imported a descriptor, adopted it as the default seed wallet, then recreated the wallet from that seed after removing the old local record. The backed-up descriptor-derived wallet ID did not match the fresh seed-origin ID, so manifest recovery rejected the same wallet (`/home/francis/bbm-i5-adopted-default-red.log`). This is reachable through current creation/import flows, not a compatibility requirement for an obsolete development database.

The existing repository recovery lookup now returns the verified local wallet ID. Exact-ID conflicts remain failures. Cross-ID resolution is limited to Bitcoin default-seed wallets and the two actual ID schemes: the descriptor's full script-identity hash and its seed-origin ID. It does not accept arbitrary references merely because their four-byte fingerprint and account path match. Neither import deduplication nor stored wallet IDs change. Manifest restoration admits the rebound record and passes successful reference mappings to metadata recovery; conflicted inventory records do not authorize metadata rebinding. Preferences, attributed frozen outpoints and the autoswap recipient are rebound together. Duplicate resulting preferences or freezes are rejected before metadata writes and retain the publication fence. Creation-time preference baselines keep their actual local IDs, preserving the earlier local-edit protection.

Focused repository/manifest/apply tests pass 43/43 (`/home/francis/bbm-i5-adopted-default-focused-expanded.log`). They exercise both ID directions, unchanged persisted identity, rejection of arbitrary IDs and full-key mismatch despite identical signer fingerprint/path facts, inventory conflict handling, all wallet-linked metadata fields and duplicate-target rejection. Existing boolean lookup assertions now assert the exact resolved wallet ID; no previous expectation was deleted. Whole-project analysis is clean (`/home/francis/bbm-i5-wallet-identities-analyze.log`). The updated full-workspace run and descriptor-adopted Android cross-installation proof are still pending at this checkpoint.

### I8 — normal application navigation and Android capture lifecycle

The all-ABI normal-app build was intentionally stopped while compiling unused Android architectures; it is not a successful-build result. The normal `lib/main.dart` emulator-only production-flavor debug build then passed in 71.9 seconds (`/home/francis/bbm-i8-normal-emulator-build.log`) and installed on owned AVD `bullvault_integration_v2_20260909`, `emulator-5584`, package `com.bullbitcoin.mobile.debug`. This binary contains the network-qualified inventory fix, but predates the subsequent wallet-reference reconciliation. Its metadata endpoint is the disposable loopback proxy, not production.

Manual navigation covered onboarding backup consent, preferences, declining crash reporting, advanced connection settings and wallet recovery selection. The physical mnemonic recovery screen exposes no word fields through accessibility inspection, and its actual Android window has `SECURE` set (`/home/francis/bbm-i8-privacy-protected.log`); an ADB screenshot attempt returned no image. After Back, `SECURE` is absent (`/home/francis/bbm-i8-privacy-after-pop.log`) and the same screenshot command produces a valid recovery-selection capture (`/home/francis/bbm-i8-recovery-options.png`). Re-entering the screen restores protection. No mnemonic was entered through this manual route, and this is not a claim of full UI recovery coverage. The captured app-process log contains no fatal exception, unhandled exception, Flutter caught exception or missing-asset marker (`/home/francis/bbm-i8-normal-app-logcat.log`).

The full identity-fix workspace run passed: 3,341 app tests plus 179 tests across all seven packages, 3,520 total (`make unit-test`, exit 0; `/home/francis/bbm-i5-wallet-identities-workspace.log`). Network identity fix `1dc73b8ef` passed normal commit hooks. The first hook attempt caught an ambiguous `ScriptType` import in the new optional Android scenario; restricting its primitives import to `Ok`/`Err` fixed that test-source compilation error. No hook was bypassed. The standalone Android test now optionally imports the public descriptor before restoring its seed in the publish phase, while the recover phase still requires an empty installation and verifies the newly derived origin ID. Its creation-count assertion distinguishes the one newly created Liquid wallet from the already-existing adopted Bitcoin wallet; the original two-new-wallet assertion remains for non-adoption runs.

Wallet-reference fix `6709f63a3` passed normal hooks, including whole-project analysis, no Dart fixes and staged-source formatting. `make bull-ui-check format-check` also completed with exit 0 and no formatting changes (`/home/francis/bbm-i5-wallet-identities-style.log`). The descriptor-adopted Android publish phase passed in 32 seconds after its build (`/home/francis/bbm-i8-adopted-default-publish.log`; APK SHA-256 `02bdeb180451845fc5bb3b1546f3c3dc01858204149dc5a43604dd105dd2a869`). It retained the same disposable server record from the preceding origin-ID test, so enabling backup first reconciled that existing backup onto the adopted default before publishing its local wallet identity. The next fresh-installation recovery phase is running on the same source and retained server database; its result is not yet claimed.

The fresh descriptor-adopted recovery phase subsequently passed in 28 seconds (`/home/francis/bbm-i8-adopted-default-recover.log`). It began with empty app storage, restored only the public-fixture seed, recovered the inheritance-enabled vault and both wallet labels plus the transaction label, asserted the fresh seed-origin wallet ID, cleared the recovery fence, republished successfully and read the remote inventory. Both phases ran source `6709f63a3` against the same disposable local server database. This closes the reproduced cross-installation default-reference defect; it does not claim the unimplemented Nostr/Bitcoin/public-password routes work. The normal app entrypoint is being rebuilt after the test runner removed its test installation.

The normal emulator-only APK was rebuilt successfully in 25.6 seconds, installed and launched on the same owned AVD (`/home/francis/bbm-i8-normal-after-identities-build.log`; SHA-256 `b1e1129e33e6528bb9fea9fdff3f231ceedec1419f13e0dd40c4ad03b7e31e88`). It has the normal app entrypoint and local metadata endpoint. This binary predates the subsequent unused-helper deletion and label-import correction. The descriptor-adopted recovery test APK hash was `3f14530e7493dc14d9cb72bbbe688148f68f3eac3ad4e00e186b30394b266aa0`.

### I8 — scoped cleanup and label-import notification correction

Reverse inspection found that `DescriptorDerivation.combinePublicBitcoinDescriptors` had no remaining callers in application or test source: the current wallet model already stores a combined descriptor. Removed only that unused 15-line helper in `55694d5fa`, preserving the active canonicalization and split paths and their validation. All 98 focused passphrase/wallet-definition tests passed (`/home/francis/bbm-i8-descriptor-cleanup-tests.log`) and normal commit hooks passed.

The label importer committed its label transaction, then checked/applied imported freezes, and only afterward notified backup listeners. Real-SQLite tests reproduced both later failure paths: labels remained committed but no change event was sent (`/home/francis/bbm-i8-label-import-notification-red.log`, two failures). Notification now follows the successful label transaction immediately. Ben's ownership checks, freeze opt-in and error propagation are unchanged. Tests also prove a rejected multi-label transaction rolls back completely and sends no notification. The focused label/backup suites pass 254/254 (`/home/francis/bbm-i8-label-import-notification-fixed.log`); a full workspace rerun is in progress. This is a minimal correction in the existing legacy `labels/application` layout, not an unrequested restructuring of the labels feature.

Two further read-path/durability questions identified during reverse inspection still need bounded reproductions before closing the core review: (1) `LabelsFacade.fetchAllStrict` currently uses the same tolerant repository enumeration as ordinary UI enrichment, so a corrupt persisted label may be silently omitted from a backup; preserve Ben's tolerant UI behavior while testing the backup's stricter requirement. (2) labels and several portable-setting owners now write this same SQLite database but their backup revisions are still recorded asynchronously by `WalletBackupTriggers`; startup publication returns early when the saved state is not dirty. Test a committed write with no delivered notification across restart before deciding the smallest correction. Reuse the existing revision recorder/transaction ownership where applicable; do not introduce another backup manager or an unconditional-publication workaround. Neither investigation is yet claimed fixed, and the full reverse-source audit/core gate remains open.

The workspace rerun including the unused-helper deletion and label-import correction passed all 3,524 tests: 3,345 app tests and 179 package tests (`make unit-test`, exit 0; `/home/francis/bbm-i8-core-final-workspace.log`). The log name denotes this verification run, not completion of the outstanding core-review questions or the entire project.

Label notification fix `0252fc203` passed normal commit hooks (whole-project analysis, Dart fix dry-run and formatting). The first hook attempt caught missing braces around one multiline conditional in the new test; after adding braces, all four import regressions passed again (`/home/francis/bbm-i8-label-notification-final.log`). No production behavior or assertion was changed to satisfy the hook. The installed normal APK still corresponds to the earlier wallet-identity checkpoint; its next rebuild must include this correction before it is described as current.

### I8 — fail closed on corrupt label backup reads

A real-facade/SQLite test reproduced the strict-read gap: a corrupt transaction label was skipped and `fetchAllStrict` returned `Ok` with incomplete contents (`/home/francis/bbm-i8-label-strict-red.log`). The existing repository/usecase now accept a strict read option, used only by the backup-facing facade method. Ordinary label enrichment still skips corrupt rows and retains valid labels; neither row is deleted. Strict reads return a failure for corruption and succeed for empty or valid inventories. Database exception contents are no longer copied into this read's failure or logger; the existing sanitization test now checks the actual failure message, not only its type. No new repository or feature layer was added. The label/backup suites pass 255 tests (`/home/francis/bbm-i8-label-strict-fixed.log`); the empty/valid/corrupt real-facade assertions are also being rechecked separately before committing.

The separate durability reproduction failed as expected: saving/deleting labels without a running notifier never records a backup revision, and injected revision-write failures do not prevent those writes (`/home/francis/bbm-i8-label-durability-red.log`, three failures). This is the next correction, not part of the strict-read fix.

### I8 — durable label and frozen-coin mutations

Strict label reads are committed as `dfca2a17c`, with six final focused tests and normal hooks passing. The first hook invocation lacked FVM on its shell PATH; the corrected invocation used Flutter 3.44.9 and passed all checks without bypassing the hook.

Labels now record their revision inside the existing SQLite write transaction. The upsert returns the actual affected row rather than SQLite's potentially unrelated last-insert ID; the regression inserts a second label before updating the first and asserts the returned ID. Type/origin edits and actual deletions dirty the backup; identical labels and missing deletions do not. A rejected batch rolls back both labels and revisions. An on-disk reopen test confirms a committed edit remains ahead of its uploaded revision even without a notifier or running backup feature.

Frozen-output writes had the same crash window, reproduced in five failing tests (`/home/francis/bbm-i8-freeze-durability-red.log`). Freeze, restore and unfreeze now commit their revision atomically. Duplicate freezes and missing unfreezes are no-ops. Freeze and recovery share the existing attributed-outpoint write path, reducing duplication. Ben's cross-wallet unfreeze matching remains by outpoint, not wallet ID. Failure injection proves all three operations roll back data and revisions and emit no change notification.

Label and freeze notifications now use the existing `recordedChanges` wiring, avoiding a second asynchronous revision increment. No new manager, schema, journal or startup-upload workaround was introduced. Verification: 259 label/backup tests passed before the freeze change (`/home/francis/bbm-i8-label-durability-fixed.log`), six expanded label durability tests passed, and all 18 final label/freeze datasource tests passed (`/home/francis/bbm-i8-metadata-durability-fixed.log`). The first expanded label test attempt had a misplaced import in the test file; it was corrected before the passing run. The last complete workspace claim remains 3,524 tests at the earlier checkpoint, not this pending checkpoint. Portable app/server settings and the separate Payjoin database still need their durability check; core-gate closure is not claimed yet.

### I8 — durable portable settings in the app database

Label/freeze atomicity is committed as `2e5afab18`; normal hooks passed. The next real-SQLite regression reproduced missing durable revisions in all 11 portable-setting write cases (22 failing mutation/rollback tests, `/home/francis/bbm-i8-settings-durability-red.log`). App preferences, autoswap configuration, custom Electrum/mempool servers and their represented settings now use the existing recorder inside their owning write transactions. Table notifications only wake the publisher through `recordedChanges` and no longer increment revisions a second time. Server deletion and multi-server transactions retain rollback behavior. Electrum batch storage reuses the existing single-server upsert within the outer transaction instead of duplicating an unrecorded replacement path.

Comparisons cover only represented settings: Tor/proxy configuration, developer flags, crash reporting, capture settings, exchange test credentials, autoswap execution bookkeeping and built-in Electrum server changes do not dirty portable backup. App environment changes do, because they select the autoswap configuration read into the snapshot. No-op stores and missing custom-server deletions do not increment revisions. No new schema or generic change manager was introduced.

The expanded checks pass all 30 tests (`/home/francis/bbm-i8-settings-durability-expanded-fixed.log`), including the existing independent mainnet/testnet autoswap test, rollback of deletes and a failing second write in an Electrum batch. The first fixed run caught a typed Drift enum predicate error; using the existing typed manager filter corrected it. Whole-project `make analyze` now reports no issues (`/home/francis/bbm-i8-settings-durability-analyze-fixed.log`). A full `make unit-test` run is in progress at this source checkpoint (`/home/francis/bbm-i8-durable-metadata-workspace.log`); no new full-suite passing count is claimed yet.

Payjoin policy belongs to its extracted package's separate SQLite database. It cannot participate in the app database transaction. Its initial watch value is currently skipped, so the same lost-notification case needs reconciliation after restart; blindly marking every startup dirty would generate unnecessary uploads. The next bounded change will compare a durable last-observed policy with the current policy before recording a change, without importing app storage into the Payjoin package or adding another publication runner. This remaining check keeps the core gate open.

### I8 — independent Payjoin policy reconciliation and cancellation

Portable settings atomicity is committed as `be55a947d`. The complete workspace run at that checkpoint passed 3,386 app tests and 179 package tests, 3,565 total (`/home/francis/bbm-i8-durable-metadata-workspace.log`). This count predates the Payjoin changes below.

A regression using the actual public `openPayjoin` API and an on-disk package database confirmed that a policy change with no backup listener survived restart but left backup clean (`/home/francis/bbm-i8-payjoin-durability-red.log`). Backup now observes the initial policy and compares all three represented scalar values against one nullable field in its existing local state row. The observation and dirty revision commit together; identical values are a no-op. Lifecycle resume retries observation, including after an injected failed transaction. No backup wire format, package database schema, additional manager or cross-database transaction was introduced.

Reconciliation uses the existing repository and use-case layer: the use-case sequences reading the policy and recording its observation; the repository owns the comparison and transaction. The locator only wires it. The public-API restart tests invoke this actual use-case and prove changed, unchanged and failed-first-observation behavior. Two additional use-case tests prove failed reads leave the whole stored state unchanged, retry works, exception contents are not exposed and programming errors are not disguised as storage failures. These five tests pass (`/home/francis/bbm-i8-payjoin-reconciliation-usecase.log`). The preceding complete backup/migration run passed 226 tests and whole-project analysis was clean (`/home/francis/bbm-i8-payjoin-durability-final.log`, `/home/francis/bbm-i8-payjoin-durability-analyze-final.log`); the consolidated checks with the final wiring are running, not yet claimed passed.

These tests also reproduced an independent package defect: cancelling the public policy stream while it awaited another change could hang shutdown. Forwarding the mapped stream with `yield*` instead of an `await for` loop fixes cancellation while preserving the existing policy results and failure mapping. A package-level public-API regression and its existing runtime test pass 2/2 (`/home/francis/bbm-i8-payjoin-package-cancel.log`); the app restart tests also enforce a bounded teardown. This small upstream-facing correction will be committed separately from app backup reconciliation.

`make build-runner` and `make drift-migrations` passed for the new local observation column. Only the unreleased v17 snapshot, its generated step and v17 test fixture changed; historical schema fixtures did not. Existing development installs at an earlier v17 shape require reset. This is not a new released compatibility target, and final published-schema consolidation remains the separately planned release gate.

### Architecture source correction

Compared the current branch with pinned Ben base `309819e31ca49c73ab48701c8c3b274e3375d10f`: `ARCHITECTURE.md` is unchanged. The added-file inventory introduces no `application/`, `adapters/`, `frameworks/` or `interface_adapters/` hierarchy; added import lines introduce no dependencies on those hierarchies, and no new `lib/core` import of feature code. The labels ports/adapters/frameworks already exist in that upstream tree; the recent fixes modified their existing operations without copying that layout into our features. This is a bounded structure/dependency check, not proof that every abstraction is necessary or that the full integration review is complete. Upstream's feature-based layered architecture remains the standard; unrelated legacy modules will not be renamed or refactored as part of these fixes.
