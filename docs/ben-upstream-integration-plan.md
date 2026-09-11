# Ben upstream integration and backup-stack consolidation

Update 2026-09-11: the user requires ONE working branch containing the core integration and the applicable distributed donor work. The older distributed-child branch proposal below is superseded. Existing donor work has now been replayed onto `integration/bullvault-metadata-deterministic-keys-v2`; see [integration-execution.md](integration-execution.md) for source-commit mapping, current verification and remaining production work. Original donor histories/worktrees are preserved, not separate delivery targets. This consolidation does not enable prototype writers in production or implement the remaining product-flow roadmap.

Historical status when written on 2026-09-09: implementation proposal only; no application/backend changes, rebase, branch creation, publication or deployment had been performed for this plan at that point. Execution has since progressed as recorded above and in the execution log. This plan precedes production work in [distributed-backups-roadmap.md](distributed-backups-roadmap.md); it does not replace that roadmap or resolve its open product decisions.

UI addendum: [bullvault-backup-recovery-ui-plan.md](bullvault-backup-recovery-ui-plan.md) specifies the subsequently requested mandatory descriptor action, Additional backup protection screen and three recovery entry points. Those are deliberate product changes in their own chunks, not silent rebase resolutions. In particular, the new manual gate supersedes preservation of the old share-sheet-plus-checkbox completion behavior.

## 1. Outcome and scope

Produce one tested integration of Ben's latest BullVault work with our metadata backup, wallet recovery, deterministic identities and private-session passphrase wallets. Then transplant the unique distributed-backup work onto that integration without losing audited fixes or promoting prototypes into production.

The architecture should become smaller where Ben has removed a need: one SQLite vault lifecycle, one descriptor importer, one PSBT verification implementation, one signing-material resolver, one metadata backup job runner. Do not invent a generalized synchronization framework, a second wallet importer, a transaction manager spanning all features, or permanent compatibility machinery for experimental installations.

Deliver three distinct outcomes, with different completion claims:

1. **Integrated core:** Ben plus our audited stack and necessary integration fixes; source parity, host checks and emulator checks pass.
2. **Consolidated development branch:** unique distributed prototypes sit on the tested core; their existing fixtures and development flows work, with unsafe public writers unavailable to production routes.
3. **Release-ready stack:** published-schema upgrade contract is settled, required hardware/platform and backend checks are complete, and any production distributed-backup work passes its own roadmap gates. Outcomes 1 and 2 do not imply outcome 3.

### Not included

- Changing spending-policy defaults, timelocks, inheritance rights or renewal consent.
- Removing passphrase wallets, adding new deterministic derivations, rotating backup credentials, or changing existing encrypted metadata bytes during the restack.
- Implementing the new server record model, public password-backed Bitcoin publication, production Nostr retention/history, or the full backup-password lifecycle. These remain separate roadmap chunks.
- A general migration of `lib/core` into packages, a UI redesign, unrelated upstream cleanup, or a rewrite of RecoverBull seed recovery.
- Automatic fee spending, public publication, production server writes, destructive emulator resets, pushes, PR edits, amendments or force-pushes as a consequence of approving this document alone.

## 2. Pinned evidence and branch topology

| Role | Ref at planning time | Evidence / use |
| --- | --- | --- |
| Ben's current head | `da6950a698473e21a5c2725538174a7fd473e5f8` | [PR #2793](https://github.com/SatoshiPortal/bullbitcoin-mobile/pull/2793), `feat/bullvault` targeting `develop`; [PR #2811](https://github.com/SatoshiPortal/bullbitcoin-mobile/pull/2811) exposes the same feature branch against the beta base. Do not integrate it twice. |
| Current develop ancestor | `eb7c4fa89c4207563a452534703cb7e9fb0451ee` | GitHub comparison reports Ben 32 ahead and 0 behind on 2026-09-09. |
| Ben base under our audited integration | `7ea4d7bfcdc86c100262f4c1d454ccbf0954d452` | Use this boundary to isolate our 32 commits. |
| Audited integration | `integration/bullvault-metadata-deterministic-keys` at `eaa5696f0a2533b6dd1474cd275e72dc484a6f46` | Worktree `/home/francis/bbm-bullvault-rebase`, clean at planning time. Primary donor for our core stack. |
| Distributed development | `distributed-resiliant-backups` at `7cf8694e6c5622c31fd2a779d36b247a910ba2d6` | Worktree `/home/francis/bbm-distributed-resiliant-backups`. Not descended from the audited integration. |
| Older test-stack boundary | `837cba24a559a5bc59beb1dbcd01b31e3092deb9` | Boundary for the ten subsequent distributed-branch commits; those ten are not all unique features. |
| Latest published release | [v6.13.1](https://github.com/SatoshiPortal/bullbitcoin-mobile/releases/tag/v6.13.1) | Published 2026-08-31; release source declares database schema 14. Recheck before finalizing migrations. |

The distributed worktree currently has an untracked, user-owned `docs/distributed-backups-roadmap.md`. Preserve it verbatim; do not stash, overwrite, move or silently commit it as part of the restack. This new plan is a separate file.

Patch comparison of Ben's latest 20 against the previous Ben base found eight unchanged patches, eight revised existing changes and four new follow-ups. Ben also rewrote earlier commits outside the latest 20. Therefore the integration unit is his complete pinned branch, not a cherry-pick of the latest 20 hashes.

### Proposed branch arrangement

```text
Ben: feat/bullvault @ da6950a69
  └─ integration/bullvault-metadata-deterministic-keys-v2
       ├─ our audited stack, adapted and verified
       ├─ narrowly scoped integration/hardening commits
       └─ integration/bullvault-distributed-backups-v2
            ├─ unique distributed prototype changes
            └─ subsequent approved distributed-roadmap work
```

Names above are proposed new branches, not existing refs. Keep the current two branches and the original 11-slice history intact as archives. A branch that includes distributed prototypes should not become the sole source for reviewing the core metadata/passphrase stack.

## 3. Rules to preserve

These are inherited behavior/security requirements, not new product choices:

1. **Wallet identity:** backup restoration retains the recorded wallet reference; descriptor import still deduplicates by actual script identity. A restored ID cannot overwrite a different wallet. Same descriptor under another ID must follow explicit conflict semantics, not silently create duplicates.
2. **Signing ownership:** ordinary stored seeds remain stored; passphrase-derived private-session material remains session-only. Persisting the already-owned passphrase-free parent mnemonic is not the same operation as persisting its derived passphrase wallet. Choose the seed from verified per-key ownership, never from signer position zero as a multisigner fallback.
3. **Lock boundary:** locked private wallets cannot sign through Bitcoin, Liquid, Payjoin, standalone PSBT or resumed-send paths. Wrong passphrase and lock are not silently converted to a persistent-store fallback.
4. **Descriptor safety:** backups contain public descriptors and public signer facts, not mnemonics, passphrases or xprvs. Preserve rejection of private descriptors before durable import/backup, independent of whether the underlying parser accepts them.
5. **Durability:** commit backup-relevant database changes with their revision. Acknowledging an older uploaded revision cannot acknowledge newer edits. Recovery/conflict fences survive restart.
6. **Vault ownership:** BullVault owns policy, lineage, activation, visibility and restoration. WalletBackup consumes its published contribution; it does not write BullVault tables directly or reconstruct policy semantics itself.
7. **Recovery truth:** importing a descriptor does not restore spending keys. Keep partial recovery, wrong-network skips, conflicts, unavailable services and missing signer access visible. No automatic adoption of an active vault based only on advertised timestamps or lineage annotations.
8. **Secrets:** no raw secrets in routes, long-lived presentation state, equality/debug output, logs, telemetry or exception messages. Capture protection must be positively confirmed before secret rendering; no promise of guaranteed memory zeroization in Dart.
9. **Publication:** integrating prototype code grants no permission to publish private BIP138 artifacts or metadata publicly, contact new production services, or spend funds.

## 4. Architecture and decision boundaries

Read the target checkout's `ARCHITECTURE.md`, `AGENTS.md`, optional local instructions and `FEATURES.md` before execution. The architecture documents did not change between the two inspected Ben heads. `ARCHITECTURE.md` takes precedence over generic skill language: existing shared wallet/seed modules remain where they are during this task, and existing domain ports are legitimate; no opportunistic package extraction or port renaming.

| Owner | Existing layers / concrete areas | Public boundary and dependencies | Required adjustment |
| --- | --- | --- | --- |
| BullVault | `domain` policy/use cases/repository; `data/bullvault_metadata_datasource.dart`, repository, codec; existing Cubits and screens | `public/bullvault_facade.dart` publishes snapshot/import contract types | Implement snapshot enumeration against SQLite and remove obsolete visibility-reconciliation calls. Keep lifecycle logic inside BullVault. New facade operations call owner use cases rather than directly adding more repository forwarding. |
| WalletBackup | Snapshot/compare/apply/job runner in `domain`; `data/bullvault_backup.dart`, state and HTTP repositories; locator/triggers | Existing `WalletBackupFacade`; consumes BullVault, manifest and labels public surfaces | Adapt the contribution, preserve canonical ordering and recovery fences; reuse the existing runner. No reverse BullVault-to-WalletBackup dependency. |
| Wallet/seed shared legacy modules | `lib/core/wallet` and `lib/core/seed` domain/data APIs; signing resolver | Existing descriptor/signing capabilities and seed-ownership APIs | Keep their location for this integration; preserve resolver mediation and full-key checks. Do not proliferate new feature business logic in core. |
| Storage infrastructure | `SqliteDatabase`, migrations, `BackupRevisionRecorder` | Inject the existing recorder into the owning persistence implementation | The recorder shares the same database/transaction as the mutation. It must not be a second database instance or an asynchronous after-commit substitute. |
| Backup Settings / onboarding | Existing UI, Cubits and own use cases | Consume feature facades; user-facing failures mapped in presentation | Preserve routes/search and distinguish key backup, metadata backup and descriptor recovery. No business logic moved into widgets. |
| Screen privacy | Existing `packages/screen_privacy` implementation and tests | Existing package API | Preserve native-positive-response checks and reference counting; adapt moved screens. No new privacy service. |
| Portable prototype | Existing `portable_backup` domain/data/presentation/UI and generic Nostr infrastructure | Production facade/locator remains roadmap work unless a narrow boundary is required by integration | Preserve development artifacts without exposing fixture helpers or raw-secret APIs as production contracts. No second global backup scheduler. |

### Existing graph drift to correct narrowly

There is a `BullVault → RecoverBull → WalletBackup → BullVault` cycle. `FEATURES.md` on the audited branch also omits the real WalletBackup-to-BullVault edge. Lazy locator closures do not remove this cycle.

Plan one separate architecture commit: move optional metadata-after-seed-recovery orchestration to the app composition boundary using a narrow completion capability/callback; remove RecoverBull's direct WalletBackup dependency. Preserve the current seed-recovery success and partial-failure behavior, and call the owning use case for the follow-up. Do not introduce a general event bus. If the actual route signatures make this larger than the existing completion workflow, stop that refactor for design review rather than expanding the public API speculatively.

`BullVaultFacade` currently exposes some repository-forwarding methods. Converge only the methods touched for the new snapshot contract to the documented facade/use-case chain in a clearly identified commit; do not refactor every facade or core repository.

### Decisions that remain explicit

- **Schema release boundary:** published schema is currently 14, making 15 the final pending revision under `AGENTS.md`. Ben currently carries 16 and our branch 17. Coordinate one release-level consolidation with Ben/develop, rather than inventing 18. Integration can be tested using the current branch numbering as a temporary scaffold, but must not be called release-ready until consolidation is resolved. If a release ships meanwhile, refresh the published baseline.
- **Experimental installs and files:** no production users exist for these features. Do not add automatic migration from branch-only key-value vault storage by default. Inventory any valued test wallets/files before resetting a test device. On-disk development DB compatibility and long-lived descriptor/recovery-file compatibility are different decisions; do not discard recovery readers simply because an app branch was unreleased.
- **Distributed storage:** the user's [2026-09-11 locked decisions](distributed-backups-roadmap.md#1-locked-product-decisions--2026-09-11) require metadata plus BIP138 on the server, password-encrypted descriptors on Nostr/Bitcoin, and no extra password-encrypted server descriptor record. Cosigner-key lookup needs no additional user-held secret; words-only server recovery extracts the descriptor from metadata. Protocol details remain to implement and verify; this does not change the completed source consolidation.
- **External actions:** actual hardware access, production deployment, release/PR coordination and any public test publication require the relevant access and authority. Missing hardware is recorded as unverified, not replaced with a mock success claim.

## 5. Ordered implementation chunks

Each chunk below is a delivery unit, not necessarily a single commit. Keep adaptations with the feature they adapt; keep independent fixes/refactors separate. The history replay may be temporarily non-compiling until its dependency set is complete; such intermediate states are not releasable milestones. Do not split it into dozens of artificial green commits or hide unrelated fixes inside conflict resolutions.

Execution order: I0 → I1 → I2–I5 → **I8 core gate** → I6 → **I8 consolidated-branch gate**. Start I7's release-schema coordination during I0; apply its agreed code as a separate patch and rerun affected gates afterward. I7 must not remain outstanding at release approval. I8 is a reusable milestone check, not permission to delay all validation until the end.

### I0 — Freeze inputs, preserve work and create the transplant manifest

**Scope:** repository/ref inventory and reproducible comparison. No app behavior change.

- Recheck Ben's PR/head and published release; pin full SHAs. If Ben moved, describe and review the delta before choosing the new base. Do not chase a moving remote silently during a long restack.
- Record worktree status, branch refs, lockfile/toolchain and all user-owned untracked work. Do not copy private `.env` files into reports or archive secrets.
- List our commits in `7ea4d7bf..eaa5696f0` and the ten commits in `837cba24a..7cf8694e6`. Give each an eventual disposition: replay unchanged, adapt, duplicate, superseded implementation with behavior preserved, or deliberately quarantined prototype.
- Prepare a new, unused worktree/branch copied from the audited integration, not the distributed branch. Existing worktrees remain untouched.
- Capture targeted baseline failures on donor/Ben where useful for attribution; prior test counts are historical, not proof for the new tree.

**Evidence commands:** `git status --short --branch`, `git worktree list`, `git log --reverse`, `git range-diff`, `git diff`, and GitHub PR/release queries. Fetch exact commit objects without modifying source branches where possible.

**Exit:** pinned refs and a complete commit manifest; all user work preserved; explicit distinction between existing defects and proposed adaptations.

### I1 — Restack the audited core on the complete Ben head

**Scope:** replay the audited 32-commit range onto pinned Ben, resolving genuine API and storage changes. Do not cherry-pick Ben's latest 20 onto the old Ben history.

**Likely areas:** `lib/core/storage/**`, wallet metadata/repositories/resolver, BullVault facade/locator and snapshot contribution, Backup Settings, onboarding, screen privacy, generated schemas and matching tests.

- Use the audited stack as the semantic donor. Preserve original source refs; perform history rewriting only on the new branch. Record old-to-new mappings.
- Inspect historical rebase/alignment commits, especially `8a5b16951` and `548884f47`, for copied upstream content. Do not let them overwrite newer Ben implementations; retain only still-required adaptations and document any superseded hunks.
- Keep Ben's SQLite lifecycle and signing-session implementation. Do not resurrect the old key-value datasource, manual visibility repair or duplicated PSBT validator to reduce conflicts.
- Reintroduce our inventory/encode/restore contribution through BullVault's published API. Add the required SQL enumeration query; return all records needed by the existing backup contract, not just the active visible wallet. Canonical sorting belongs at the snapshot boundary.
- Remove `reconcileVisibility` from `data/bullvault_backup.dart`, locator construction and mocks once restoration/activation uses Ben's atomic operations. Test the actual resulting visibility instead of merely deleting the old invocation assertion.
- Adapt `BullVaultRestoreResult.mobileAccess` and all changed signing return types. Keep wallet labels, reference-preserving generic restore and created/conflict results.
- Regenerate ignored code and inspect tracked generated changes; a parser or fixture generated from the same implementation is not an independent identity oracle.
- Avoid broad take-ours/take-theirs resolutions. Every nontrivial hunk gets a short reason tied to an API change, preserved requirement or separate defect.

**Tests:** `wallet_definition_backup_test.dart`, `bullvault_backup_test.dart`, BullVault repository/restore/renewal tests, signing resolver/private-session boundary tests, backup snapshot codec/contents tests and changed settings/UI tests.

**Exit:** compiling integration, targeted suites green; every donor commit mapped; no undocumented lost behavior. Full two-way fidelity review is repeated in I8.

Historical mechanical starting point from the original proposal, retained for provenance only: do not rerun these commands on the already-created integration worktree. Actual pins and replay decisions are recorded in the execution log.

```sh
git -C /home/francis/bbm-bullvault-rebase worktree add -b integration/bullvault-metadata-deterministic-keys-v2 /home/francis/bbm-bullvault-integration-v2 eaa5696f0a2533b6dd1474cd275e72dc484a6f46
git -C /home/francis/bbm-bullvault-integration-v2 rebase --onto da6950a698473e21a5c2725538174a7fd473e5f8 7ea4d7bfcdc86c100262f4c1d454ccbf0954d452
```

This isolates only our audited range on the new worktree. It is not a conflict-resolution script: stop at each conflict, inspect both source versions, apply the rules above and update the manifest before continuing. A changed upstream head requires changing the pinned plan first, not substituting `origin/feat/bullvault` mid-operation.

### I2 — Prove preservation of audited metadata durability fixes

**Scope:** retain fixes that already exist in `eaa5696f0`; do not reimplement them as another scheduler or migration system.

**Files:** `lib/core/storage/backup_revision_recorder.dart`, `lib/core/wallet/data/datasources/wallet_metadata_datasource.dart`, `wallet_backup/domain/usecases/publish_wallet_backup_usecase.dart`, its state repository/recovery pipeline, manifest persistence and existing tests.

Required donor behavior:

| Audited commit | Behavior that must survive | Failure to reproduce in a test |
| --- | --- | --- |
| `42de3be62` | Metadata write and backup revision commit together | Crash after wallet edit must not leave the edit permanently clean. |
| `2f132e720` | Identical remote content acknowledges an upload whose reply was lost | Server commits, response disappears, retry must not create a spurious permanent conflict. |
| `d34c4d1c0` | Conflict fence precedes accepting the competing checkpoint | Crash between state writes must not enable automatic overwrite of another device's head. |
| `0f5e892ce` | Retained local data after file recovery remains dirty | Partial recovery must not suppress later publication of retained data. |
| `e0edc364a` | Remove unused manifest restore policy | Do not resurrect dead policy plumbing during replay. |

Also preserve existing serial execution, deadlines, unsupported-version fences, canonical deep equality and the UI's explicit conflict decision. Test a mutation during snapshot/upload: acknowledge only the captured revision and retain newer dirty work. Test failure of the revision write itself: the associated data write must roll back.

**Exit:** behavioral tests use real in-memory/on-disk SQLite where transaction/restart behavior matters. No missing-fix gaps remain merely because all imports compile.

### I3 — Make BullVault changes reliably trigger metadata backup

**Scope:** the small new integration that Ben's SQLite move enables.

**Files:** BullVault SQL datasource/repository and public contribution, `BackupRevisionRecorder`, `wallet_backup_locator.dart`, `watchers/wallet_backup_triggers.dart`, existing runner/state APIs and tests.

1. Enumerate every write that changes the serialized vault contribution: record creation/deletion, represented lifecycle status, recovery package changes, generation transitions and relevant labels. Separate persisted fields that are not in the snapshot; do not trigger uploads for every internal reservation/read.
2. Record the revision inside the same SQLite transaction as each represented mutation, including multi-record renewal and visibility changes that bypass `WalletMetadataDatasource`. Do not call the recorder after the outer transaction finishes.
3. Emit/wire a post-commit wake-up through an owning watch use case/public contract into the existing `recordedChanges` path. No second revision increment in the trigger. Rollbacks must not report committed changes. Keep startup/resume retry so a lost in-memory wake-up cannot lose durable work.
4. Compare represented values rather than object/list identity; a no-op store should not create endless uploads. Keep recovery fences intact while restored records correctly dirty their owning snapshot.

**Tests:** clean backup → create/activate/renew/change package/delete → automatic publication with no unrelated edit or manual backup button; no-op store does not dirty; crash before commit rolls back both; restart after commit/before notification still publishes; change during upload produces a later publication; failed/rolled-back renewal cannot mark an unavailable descriptor as backed up. Include predecessor and successor in the snapshot when both remain relevant.

**Exit:** each represented mutation is accounted for; one existing runner handles it; no BullVault-to-WalletBackup dependency or generic transaction framework added.

### I4 — Preserve private signing while adopting canonical seed ownership

**Scope:** seed identity, material resolution and changed signing APIs—not a new key-management feature.

**Files:** `lib/core/wallet/data/wallet_signing_material_resolver.dart`, `data/repositories/bitcoin_wallet_repository.dart`, `wallet_repository.dart`, `lib/core/seed/data/repository/seed_repository.dart`, BullVault key/restore use cases, existing Payjoin adapter, Send and PSBT consumers.

- Use Ben's `localSeedFingerprint`/`localSeedFingerprints` semantics for stored ownership. Match actual derived xpub/origin/network before signing or marking a signer local; a fingerprint alone is not proof.
- Audit each new `ensureCanonicalSeed` caller. Permit storage of an already-authorized base seed; never persist the passphrase or private-session-derived material as a shortcut to support Ben's per-key lookup.
- Keep resolver mediation for each descriptor key and ordinary single-sig/Payjoin signing. Integrate Ben's originless-descriptor and full derived-xpub verification changes. Avoid a fallback that uses primary signer metadata for all keys.
- Carry the typed lock failure through the real `signPsbt` boundary. Revalidate capability when asynchronous signing work resumes; a late unlock/derivation result after backgrounding cannot reopen a session.
- Keep Ben's combined-and-validated external PSBT result and pending submission validation. Do not bypass frozen/spent-input or output checks just to make backup publication or tests succeed.

**Tests:** unlocked/locked private wallet, wrong passphrase, background lock during in-flight work, two different local signers, local plus hardware signers, repeated keys, originless descriptors, resumed signing, external partial PSBT substitution and Payjoin. Spy on the persistent seed datasource: private-wallet resolution must cause no fallback reads or writes. Exercise Bitcoin and Liquid private-session consumers already in our stack. Audit `SeedModel`, session material and changed parser/result types for generated `toString`, equality/hash behavior and exception interpolation over secrets; add focused regression tests where new or preserved boundaries require them, not a parallel secret-type hierarchy.

**Exit:** both Ben's multisigner flows and our private-wallet flows pass through actual public signing entry points; no secrets appear in captured failure/log output.

### I5 — Close the affected recovery and privacy seams

Split the following into separate coherent fixes, not one catch-all cleanup commit.

**I5a: metadata recovery and ownership.** Adapt the existing BullVault restore integration to `mobileAccess` without equating import success with spending access. Preserve recorded generic-wallet IDs, labels, conflict semantics, rollback and older funded generations. Reproduce and fix the previously identified watch-only-to-local upgrade retaining stale provenance/passphrase facts if it still exists after replay. Update only facts supported by successful key verification; never infer ownership from labels or signer zero. Test wrong key, repeated import, partial failure and a restored record under an existing wallet ID. Confirm full-key validation rejects adversarial collisions/annotations.

**I5b: physical onboarding continuity.** Reproduce the known physical-recovery path that drops newly created wallet IDs before metadata recovery. Areas: `RecoverOnboardingWalletUsecase`, its caller and WalletBackup recovery invocation. Pass the actual created IDs through the existing result/context where needed, so defaults just created in this operation are not mistaken for unrelated local conflicts. Preserve real pre-existing wallet preferences. Test the complete physical restore → metadata preview/apply → enable Data Backup flow, not only the seed-backup verification helper. Do not redesign the onboarding feature.

**I5c: moved secret screens.** Adapt the positive-response privacy guard to Ben's extracted inheritance mnemonic flow, inheritance import, mobile passphrase entry and restoration screens. Gate rendering on successful protection; rejection/error shows a nonsecret failure state. Verify nested push/pop reference counts, disposal while enable is pending, backgrounding, retry and overlapping protected screens. Exclude secrets from semantics. Consolidate the audited privacy patch with distributed commit `309e0569f`, retaining its stricter expected-exception catch where appropriate rather than replaying two conflicting fixes.

**I5d: narrow dependency-cycle correction.** Apply the app-composed recovery completion change from section 4 as its own refactor with `FEATURES.md`, startup/DI and recovery-cancellation tests. Do not change failure policy or make successful seed recovery conditional on an online metadata server.

**Tests/exit:** actual relevant UI/use-case flows pass; secret frames remain absent until protection succeeds; failed metadata follow-up does not erase recovered keys or report complete metadata recovery. Every purported fix has a reproduced pre-fix failure or is labeled an integration adaptation.

### I6 — Carry over unique distributed work, without reviving obsolete behavior

**Scope:** branch consolidation and preservation of development assets, not production implementation of the distributed roadmap.

Replay the unique work onto the same integration branch after the core gate; do not create a distributed-v2 child. This carry-over is now committed at `cd350ba78`, `9ffb26f0b` and `2eaef4cc2`, with the exact donor mapping and current verification in the execution log. The original manifest below remains the fidelity checklist; validate final behavior rather than relying on patch IDs alone.

| Source commit | Planned disposition |
| --- | --- |
| `bc58e0b69` orphaned RecoverBull gate | Already represented by audited `d1e42efeb`; do not duplicate. |
| `80cf9ac6d` passphrase settings entry | Already represented by audited `dd04503cb`; do not duplicate. |
| `bda56ac83` BIP138/Nostr prototype | Preserve codec, fixtures and historical evidence; public BIP138 publication must not become a production action. |
| `8232640f0` distributed descriptor prototype | Port unique development code; adapt to new BullVault APIs. Isolated prototype wallet storage remains a harness, not app recovery. |
| `2d6ea7664` testnet4 evidence | Preserve fixtures/docs; old transactions are evidence for the old profile only. |
| `406e3019e` five-output prototype | Preserve required tests/evidence without presenting it as the roadmap's one-OP_RETURN password profile. Keep obsolete writer out of production routes. |
| `309e0569f` native capture refusal | Reconcile with audited `b4427ce82` and I5c; retain unique tests and meaningful error-handling differences. |
| `aa5a80b6b` shared Nostr verification/transport | Port shared implementation and its tests; do not fork it back into each backup feature. |
| `1ec76af73` portable artifacts/password Nostr | Carry the useful feature and fixtures together with its subsequent cipher replacement; do not publish an intermediate age-cipher milestone. |
| `7cf8694e6` RecoverBull encryption reuse | Preserve final library-backed encryption and interoperability vectors; no custom replacement cipher. |

**Files:** `lib/features/portable_backup/**`, BullVault descriptor/Bitcoin prototype repositories and codecs, shared Nostr infrastructure, `lib/core/utils/recoverbull_encryption.dart`, development entry points and corresponding tests/docs.

Keep the existing wire/credential vectors unchanged in this chunk. Inventory prototype import and publication entry points; confine fixtures/public writers to explicit development harnesses where necessary, using existing development mechanisms rather than introducing a new flag framework. Never use real user material for public regression tests.

**Tests:** portable repository/Cubit/UI suites; BIP138 and Bitcoin codec/repository suites; shared Nostr tests; independent cipher vectors where the existing harness is available; core parity tests again after transplant. Preserve the user's untracked roadmap separately and reference its revised baseline without rewriting its decisions.

**Exit:** unique distributed behavior accounted for, audited durability fixes still present, no obsolete public BIP138 writer exposed in production navigation, and no claim that prototype recovery is production restoration.

### I7 — Resolve the final database release shape

**Scope:** a separate migration-convergence change coordinated with Ben/develop; not a new revision for each feature.

**Files:** `lib/core/storage/migrations/**`, `sqlite_database.dart`, schema snapshots/steps, migration tests and fixtures. Follow the owning package's independent schema history for package databases such as bull_payjoin.

- Recheck latest published tag and immutable schemas. With the currently verified release at schema 14, aggregate unreleased develop, Ben and our changes into final pending schema 15. Do not simply rename `17` to `15`; rewrite the combined migration against the actual schema-14 tables/columns and resulting normalized signer model.
- Preserve all published upgrade sources and immutable fixtures. Retain no v16/v17 development migration merely to support a disposable development DB. Do not delete valued development data: provide export/reinstall guidance and obtain approval before resetting an actual device.
- Include normalized signer rows, send/pending transaction changes, BullVault record/reservation tables, metadata/manifest/backup state and provenance/birthday fields in a final-schema checklist. Explicitly prove provenance backfill against the real source schema, not a signer-zero column assumption inherited from an intermediate migration.
- Test latest published schema → final schema with populated data, relevant older supported chains, fresh installation and foreign-key/integrity checks. Verify identical final table/index/constraint structure and preserved labels/wallet identities/signers. Inject migration failure to prove rollback/no false successful version stamp.
- Publish the proposed consolidation diff for coordination only when authorized. If Ben adopts it first, restack the child onto that exact head and revalidate; do not ship parallel incompatible migrations numbered the same.

**Exit:** one agreed pending app revision after the latest published revision; no release approval while only temporary branch numbering has been tested. This coordination can proceed while I2–I6 are being prepared, but its final schema must be part of the final release candidate checks.

### I8 — Two-way fidelity, end-to-end verification and review packaging

**Scope:** validate the final integrated source; report limitations rather than substituting old green counts.

- Compare each of our original 32 patches to its restacked equivalent. Account for changed/dropped hunks, test expectations and explicit supersessions. Preserve a separate mapping for the ten distributed donor commits.
- Reverse-check the diff against pinned Ben: enumerate every touched upstream signing, lifecycle, seed, UI and migration file. Explain each departure. No lost hardware support, weaker PSBT validation, restored manual rollback machinery or silently removed test.
- Audit tests for vacuity: verify real sign/restore entry points, independent expected wallet references/addresses, actual resulting visibility, exact conflict/created semantics and changed ordering. Passing counts alone are insufficient; explain removed, replaced and added tests.
- Run the host/device/security gates in section 6. Perform final simplification: remove now-unused DI bindings, reconciliation types/mocks, redundant wrappers and superseded docs; keep historical evidence and necessary readers.
- Produce a brief integration report containing source SHAs, old/new commit map, deliberate merge decisions, test commands/results, generated schema evidence, emulator/hardware limitations and unresolved release dependencies.

**Exit:** all required gates for the claimed milestone pass on the final SHA. Integrated core can be reviewed separately from distributed prototypes. No declaration of production readiness based only on compilation or mocked hardware.

## 6. Verification and security plan

### Tooling and build order

Use FVM and the checked-out makefile; `.fvmrc` is authoritative. Read unknown CLI flags with `--help`. `make deps` enforces the lockfile; do not use `make deps-update` for conflict convenience. Do not run Android builds concurrently with host native-asset tests in this environment.

```sh
make deps
make build-runner
make translations
make analyze
make fix-check
make format-check
make bull-ui-check
make unit-test
```

`make checks` is the consolidated analyze/UI/fix/format/unit gate; do not run all component gates twice merely for ceremony. Run targeted tests during a chunk with `fvm flutter test <existing-test-path>` or the appropriate package's `fvm dart test`, then the full gate at an integration milestone. Analyze the whole project, never only `lib test` or a changed file. `fvm dart fix --dry-run` must report `Nothing to fix!`; inspect proposed fixes rather than applying unrelated changes blindly.

Run `make drift-migrations` when schema inputs change, inspect generated output in both the app and bull_payjoin, then rerun codegen/migration tests. Manage localization via `tools/arb.dart`, not manual ARB editing; run translations after input changes. The existing `bull-ui-check` covers coins UI, not a security review of backup screens.

Run the repository's integration-test aggregator on an explicitly identified disposable device. The make target can uninstall the app; do not run it against the user's existing emulator wallet. After integration tests, rebuild the normal entry point with the documented `fvm flutter build apk --debug --flavor production` and install it on the isolated device; a test-entrypoint APK is not the deliverable app. Reproducible/container release builds use `make android` in the release gate.

### Required behavior matrix

| Area | Cases | Observable proof |
| --- | --- | --- |
| Generic wallet definitions | Seed-origin IDs, descriptor IDs, duplicate scripts/different IDs, labels, private descriptors, wrong network | Stable reference and addresses; correct created/conflict result; rejected input leaves no partial wallet. |
| Vault lifecycle | Create, activate, renew, cancel/resume, restore old/new generation, predecessor with funds | Atomic record/visibility changes; relevant complete descriptors retained; no invented lineage or policy. |
| Automatic backup | Vault edit with otherwise idle app, no-op write, restart, offline/retry, update during upload | Revision and represented data survive together; exact snapshot acknowledged; later work remains dirty. |
| Remote conflict | Lost reply, authentic different head, unknown version, state-write failure | Identical data acknowledged; different/unsupported data remains fenced and is never auto-overwritten. |
| Recovery apply | Fresh app after seed setup and previously initialized app, physical and encrypted seed routes, partial file restore, local preferences, unavailable metadata | Truthful partial state; preserved local data; successful key recovery independent of online metadata; correct newly created wallet IDs. Pre-seed descriptor-only entry remains the separately identified P7 work. |
| Signing | Local, hardware, multisigner, private locked/unlocked, wrong passphrase, resumed PSBT and Payjoin | Actual valid signatures when authorized; no private-store fallback; validation rejects altered outputs/keys. |
| Capture protection | Native true/false/null/error, delayed enable, nested screens, early disposal, background/resume | No secret frame/semantics before protection; no premature release or permanently retained protection. |
| Durable files/schema | Published populated DB upgrade, fresh DB, archived supported recovery files | Stable identity/data, converged schema, explicit unsupported-version behavior; no silent legacy-format reinterpretation. |
| Prototype preservation | Offline vectors, shared Nostr verification, development entry points | Same final ciphertext/credential semantics; private/public boundaries; normal routes do not enable old public writers. |

### Emulator observation

Use an isolated emulator and public synthetic seeds only. Record final commit, APK hash, app flavor, device identifier, network and scenario in the evidence bundle.

1. Fresh onboarding → physical backup → Data Backup setup; separately repeat the RecoverBull seed-vault route with a controlled available/unavailable service.
2. Create a practice vault, export its package, complete setup, rename/edit a backed-up field and observe automatic backup without pressing a manual publish button.
3. Prepare and complete a practice renewal with test funds where available; leave a predecessor funded in the appropriate test scenario and verify both recovery packages remain available.
4. Mount a private passphrase wallet, sign a controlled transaction/PSBT, background the app, return and attempt signing again. Verify the lock failure and successful re-unlock without persistent private material.
5. Recover metadata into a separate fresh test profile; repeat with network failures, process death/restart and conflicting local changes. Check UI status against actual persistent state.
6. Navigate moved secret screens and nested verification; observe rendering/capture behavior and lifecycle logs. Screenshots alone do not prove native blocking: combine widget tests, package tests and on-device capture attempts using synthetic material.
7. For the distributed branch, run the development file/Nostr recovery harness if available and authorized. Mark it as harness recovery, not production wallet import. New public Bitcoin/password-profile proofs belong to the production roadmap, not to this restack.

Collect app/native logs and controlled server request summaries; use test-local logging/Sentry sinks and never enable production telemetry to obtain evidence. Search for known synthetic mnemonic/passphrase/xprv canaries in logs, exception output, persisted preferences and diagnostic exports. Normal network logs must not contain raw descriptors/identities unnecessarily; secrets must never appear. Do not publish raw sensitive logs in PRs. Inspect retry storms, unhandled exceptions, missing backup wake-ups, stale UI success and SQLite errors.

### Non-emulator limits

Hardware registration/signing tests need actual supported devices; mocks prove contracts, not USB/Bluetooth, firmware or device policy support. Timelocked spending should use regtest or a genuine short practice policy, not an assumed clock jump on a public chain. Android verification does not establish iOS screen-capture behavior; record required macOS/iOS checks before release. Backend contract tests must identify the actual metadata server revision/environment; no backend change is assumed necessary merely to integrate Ben's commits.

## 7. Review methodology and simplification stop rules

The user requested solo work. Apply the planning skill's seven lenses sequentially; do not spawn agents or claim independent multi-reviewer assurance. During later implementation, keep that constraint unless the user explicitly changes it.

For each coherent chunk:

1. Implement only the chunk and its tests; list preserved invariants and any deliberate deletions.
2. Run targeted checks and necessary generation, then applicable whole-project gates.
3. Review through architecture, evidence/unsupported assumptions, Dart/async correctness, UX, over-engineering, deletion/scope and repository-compliance lenses. Include security explicitly in signing, recovery, persistence and UI reviews.
4. Classify findings as fix now, separately scoped follow-up with a safe reason, or blocked on a real external decision. Fix-now includes key leaks, loss/overwrite risks, altered spending authority, suppressed failures and unproven required behavior.
5. Fix findings and re-review material changes with affected tests. Do not rely on the earlier pre-fix pass.
6. Continue only when the chunk's exit criteria hold. Mark a missing hardware/backend/device proof as missing rather than silently dropping it.

Adversarial simplification checks:

- Can an existing owner/use case/recorder solve this? Prefer that over a new service.
- Is the proposed compatibility layer protecting shipped data or only an unreleased branch's DB? If only the latter, omit it unless explicitly requested.
- Does this field/record/event change the actual backup projection or a demonstrated recovery requirement? If not, do not add permanent backup state for it.
- Can we delete the old path now that Ben has a transactional implementation? Delete it instead of retaining two selectable engines.
- Is a test proving the public behavior, or only matching the mocks we just changed? Keep the public-behavior proof.
- Does moving a folder or renaming a class help the integration? If not, defer it.
- Is this really restack work, or production distributed-backup work? Keep the latter in separately scoped roadmap chunks on the same working branch; do not present source consolidation as completion of those flows.

No blanket size target or arbitrary class-count target: a small failure-injection test or transaction boundary is justified by a concrete loss scenario, not by aesthetic abstraction.

## 8. PR and integration procedure

1. Keep Ben's full branch as the parent. Do not merge the alternate beta PR as an additional feature stack.
2. Use `integration/bullvault-metadata-deterministic-keys-v2` as the single working branch for our complete stack, integration fixes and consolidated distributed work. Prepare its PR only when authorized to push/open it. While Ben is pending, his feature branch is the comparison base for reviewing our delta; clearly label prototype-only code and unfinished production gates.
3. Preserve the original 11-slice archive and publish an old-to-new mapping in review documentation. Do not rewrite historical archive PRs merely to make the new integration look cleaner. Group dependent commits for review by storage/manifest, protocol/engine, recovery/settings, and private signing; do not create new PRs for every helper.
4. Keep old core/distributed branches as archives, not separate delivery targets. Review the consolidated prototype commits as their own source ranges within the single branch; production enablement still requires its own correctness/security and UX evidence.
5. Offer narrowly upstream-relevant fixes, such as schema consolidation or secret-screen gating, to Ben as separate diffs when coordination is authorized. Do not silently edit or force-push his branch. If he adopts a fix, remove only the now-equivalent child patch after checking behavior.
6. After Ben merges, inspect the actual merged tree. If he was squash-merged, do not replay his entire rewritten history; transplant only our child commits onto the actual merged base and repeat range-diff and impacted tests. If upstream changes materially, refresh the integration evidence.
7. Continue the remaining approved production work and polish on that same branch. Preserve the audit-fix checklist as a behavior contract, not a list of hashes expected to remain identical forever.
8. No force-push or PR retarget operation is pre-authorized by this plan. Prepare the local candidate and report the exact proposed external action when needed.

### If integration or testing fails

Stop at the failing new branch/worktree and retain its logs and conflict manifest. Original branches remain the recovery point; do not reset the user's source worktrees. An approved abort applies only to the new worktree and must preserve any useful resolution work first. A code rollback is not a database downgrade: never install an older APK over a valuable newer-schema profile and assume it is safe. Use the isolated test profile or an explicitly approved exported/restored fixture. Preserve remote records and original recovery files; this plan requires no deletion of them. Any later public publication cannot be undone by reverting a commit.

## 9. Handoff to the distributed-backup roadmap

After consolidation, update a separate progress note with the new baseline and actual gates passed. Do not mark entire roadmap phases complete because integration made them easier.

| Existing roadmap work | Effect of this integration |
| --- | --- |
| P0/P1 recovery contract and formats | Still required. No new derivation, server inventory or wire profile decided here. |
| P2 boundaries | Scoped dependency-cycle correction can satisfy that subtask; typed public/private artifact APIs and production portable facade remain to verify/implement. |
| P3 password lifecycle | Private-wallet privacy fixes are reusable protection, not completion of backup-password display/confirmation/re-entry. |
| P4/P5 server and metadata credential migration | Still separate. Reassess compatibility scope against actually supported artifacts, not an assumption that all prototype profiles shipped. |
| P7 fresh-app descriptor recovery | Ben's restore result distinguishes access, but its default-seed prerequisite remains. Next narrow recovery change: make local seed matching optional, preserve validation/rollback, and expose descriptor-only import through BullVault's owner. Full P7 additionally needs pre-onboarding entry, file credential flow, persistent app import and scanning tests. Do not mark it complete after an importer unit test. |
| P8–P10 Nostr/Bitcoin | Shared validation and transport can be reused; existing public prototype evidence does not validate the new password profile or durable production publication. |
| P11 lifecycle/status | SQLite revision integration helps metadata publication. Independent private/Nostr/Bitcoin destination status and receipts remain separate work. |
| P12 independent recovery/release | Still requires real final-profile recovery, security review, hardware/platform evidence and approved rollout. |

## 10. Acceptance checklist

- [ ] Pinned source refs and user-owned files preserved; no work lost.
- [ ] Every audited-core and distributed donor commit has a disposition and evidence.
- [ ] Ben's SQLite lifecycle, shared signing validation and hardware support retained.
- [ ] Recorded wallet IDs and script-identity deduplication both preserved.
- [ ] Audited durability fixes retained and failure-injection tests pass.
- [ ] BullVault represented changes automatically dirty and wake the existing backup runner.
- [ ] Private-session signing never falls back to persistent private material; full-key ownership checks hold.
- [ ] Affected recovery/onboarding paths preserve new-wallet context and truthful partial state.
- [ ] Moved secret screens positively gate rendering and nested protection releases correctly.
- [ ] Scoped dependency cycle removed; touched feature graph matches imports.
- [ ] Distributed prototypes preserved without enabling obsolete public writers or changing wire vectors.
- [ ] Published-schema upgrade and fresh-install convergence verified for the agreed final pending schema.
- [ ] Final host checks and isolated-emulator scenarios run on the delivered SHA; missing hardware/iOS/backend proofs explicitly listed.
- [ ] Two-way fidelity and test-integrity review completed after final fixes.
- [ ] Core and distributed review branches remain separable; no production-ready claim exceeds the recorded evidence.

Planning methodology: the `bullbitcoin-mobile-planning-agents` skill supplied the architecture grounding, seven review lenses and chunk/exit-criterion structure. All lenses were applied by one planner in accordance with the user's explicit solo-work instruction; no subagents or independent-agent review were used. This plan was challenged for scope, unsupported migration assumptions, duplicate framework work, weak test proofs and hidden publication authority before handoff.
