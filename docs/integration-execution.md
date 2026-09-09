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

Review remains solo under the user's no-subagent instruction, applying all seven review lenses plus security. No independent multi-agent review is claimed.

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
- I4: verify canonical seed ownership throughout signing and backup callers. Exercise lock during awaited signing work and invocation of an already-created Payjoin signing callback after lock; the current callback retains a native signer and is not covered by testing only construction after lock.
- I5: prove restore status/ownership/lineage behavior against actual SQLite, review remaining privacy lifecycle races, and remove the recovery dependency cycle through app composition.
- Concrete remaining privacy sites: `lib/core/wallet/data/payjoin_wallet_adapter.dart:66` returns the native signing callback directly after loading private material; callback invocation after lock needs its own test and capability check. `lib/features/bullvault/ui/bullvault_onboarding_screen.dart:813` still enables protection without waiting before building the mobile-passphrase input. Neither site was changed by the post-replay fixes recorded here.
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
