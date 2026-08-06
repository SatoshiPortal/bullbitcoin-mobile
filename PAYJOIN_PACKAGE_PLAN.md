# Payjoin Package Extraction Plan

Status: approved for implementation

Date: 2026-07-30

Target branch: `payjoin-package-infrastructure`

Base: `payjoin-reliability-hardening` at merge commit `785310254`

Final PR target: `develop`

## Goal

Extract Payjoin into the pure-Dart workspace package `packages/bull_payjoin`, with its protocol engine, policy, failures, persistence, migrations, and public API owned by that package. The same branch first imports the required `packages/primitives` slice and contains the already-consolidated Exchange UX commits.

The completed extraction removes `lib/core/payjoin/` and does not create `lib/features/payjoin/`. Payjoin UI remains in the user-facing features that own each flow: send, receive, buy, sell, pay, transactions, settings, and status.

## Non-goals

- Do not create Payjoin screens, blocs, routes, or localization inside the package.
- Do not move Payjoin-specific UI into `bull_ui`; `bull_ui` remains domain-agnostic.
- Do not broaden the UI migration beyond `BullAsyncStatus` and the approved generic `BullSuccessScreen` consolidation.
- Do not expose Drift rows, PDK objects, wallet models, seed models, or other data-layer types.
- Do not make the package depend on `bb_mobile`, a feature package, `get_it`, Flutter, or `path_provider`.
- Do not preserve the current public repository and datasource surface after consumers have migrated.
- Do not add further Payjoin or Exchange behavior while moving it. The pre-existing functional commits and the extraction commits remain separate review ranges in the same final PR.
- Do not drop the legacy Payjoin tables in the release that performs the cutover.

## Decisions

### Package name

Use directory `packages/bull_payjoin`, package name `bull_payjoin`, and public library `lib/bull_payjoin.dart`.

The existing FFI dependency is already named `payjoin`, so naming the workspace package `payjoin` would collide in Pub's single package namespace. `bull_payjoin` keeps the upstream dependency's established name and makes ownership explicit.

The root app adds `bull_payjoin:` to its dependencies and lists `packages/bull_payjoin` under `workspace:`. The `bull_payjoin` package owns the pinned Git dependency on upstream `payjoin`; the root app removes its direct dependency after cutover.

Pub workspaces use one root `pubspec.lock`. Do not add `packages/bull_payjoin/pubspec.lock`: current Pub deletes member lockfiles and resolves every member through the root lockfile. The contrary comments in `pubspec.yaml`, `makefile`, and `AGENTS.md` must be corrected as part of the first Payjoin package delivery.

### Shared primitives

Include the existing `packages/primitives` design from draft PR #2394 as the first extraction commit in this branch. Its public surface supplies the canonical `Failure`, `Result`, `BitcoinNetwork`, and other cross-package value types required by `bull_payjoin` without creating a dependency cycle back to `bb_mobile`.

Import only the primitives package slice and its workspace/root migrations, not the Secrets refactor from #2394. Coordinate #2394 afterward so it drops or reconciles the duplicated primitives commits rather than defining a second package or second `Failure`/`Result` family.

Add the shared `Outpoint` value to `primitives` as part of this slice because both wallet send preparation and `bull_payjoin` need the same transaction-output identity.

### Bounded UI Kit migration

Keep `BullAsyncStatus` in `bull_ui`; it is already domain-agnostic and shared by Buy and Sell. Features continue mapping `OrderPayjoinOutcome` to its generic visual states and supplying localized copy.

Replace the newly added root `SuccessScreenScaffold` with `BullSuccessScreen` in `bull_ui`, implemented from `BullScaffold`, `BullTopBar`, Bull theme tokens, and caller-supplied content/actions. Adapt Buy, Sell, and Pay success screens to it without moving timers, BLoCs, routing, assets, localization, order mapping, or feature actions into the design system.

Do not move `feeSelectionRowLabel`, `FeeOptionsModal`, fee entities, Payjoin outcome mapping, SINPE UI, payout-method UI, or transaction widgets into `bull_ui`; they depend on application domain or localization. Any broader UI Kit migration is follow-up work.

### Public API shape

Use one instance facade named `Payjoin`, composed from narrow role interfaces:

```dart
final class Payjoin {
  final PayjoinSender sender;
  final PayjoinReceiver receiver;
  final PayjoinSessions sessions;
  final PayjoinPolicyAccess policy;
  final PayjoinDiagnostics diagnostics;

  const Payjoin({
    required this.sender,
    required this.receiver,
    required this.sessions,
    required this.policy,
    required this.diagnostics,
  });

  factory Payjoin.unavailable(PayjoinFailure failure) = _UnavailablePayjoin;
}
```

The nested API gives callers a discoverable vocabulary such as `payjoin.sender.start(...)` and `payjoin.sessions.watch(...)`, while the role interfaces prevent a sender-only consumer from depending on receiver, policy, diagnostics, or lifecycle operations.

All roles delegate to one package-internal engine instance. They do not own separate repositories, databases, stream controllers, locks, or timers. Splitting the public capability surface therefore does not split runtime state.

Register the roles separately in the app composition root:

```dart
locator.registerSingleton<PayjoinSender>(payjoin.sender);
locator.registerSingleton<PayjoinReceiver>(payjoin.receiver);
locator.registerSingleton<PayjoinSessions>(payjoin.sessions);
locator.registerSingleton<PayjoinPolicyAccess>(payjoin.policy);
locator.registerSingleton<PayjoinDiagnostics>(payjoin.diagnostics);
```

Feature use-cases inject the narrow role they need. They do not inject the full `Payjoin` aggregate merely to reach one member. A use-case that genuinely coordinates multiple roles receives those roles explicitly.

This is a Facade plus Role Interface design, not a collection of independent service implementations. It follows the repository's facade boundary while applying interface segregation where substitutability and capability restriction are concrete requirements.

### Session naming

Rename the current sealed entity `Payjoin` to `PayjoinSession` so `Payjoin` can name the package facade without ambiguity.

Rename its variants to `PayjoinSenderSession` and `PayjoinReceiverSession`. Keep `PayjoinStatus` and the rich domain behavior, including `isOngoing`, `canManuallyBroadcastOriginal`, and privacy-safe `logRef` handling.

The migration must preserve persisted IDs and protocol fields exactly. Changing sender IDs away from their current URI representation is useful privacy hardening, but it is a behavior and schema change and therefore belongs in a later PR.

### Lifecycle

Keep application lifecycle outside `Payjoin.sessions`. Session queries describe persisted business state; app startup, foreground resumption, and teardown control the process-wide engine.

Expose lifecycle only to the shell:

```dart
abstract interface class PayjoinLifecycle {
  Payjoin get payjoin;

  @useResult
  Future<Result<void, PayjoinFailure>> resume();

  Future<void> dispose();
}

@useResult
Future<Result<PayjoinLifecycle, PayjoinFailure>> openPayjoin({
  required String databasePath,
  required PayjoinWalletPort wallet,
  required PayjoinBlockchainPort blockchain,
  required PayjoinTransactionPort transactions,
  required PayjoinLabelsPort labels,
  required PayjoinLegacyDataPort legacyData,
  required PayjoinLogPort log,
});
```

`openPayjoin` opens and migrates `payjoin.sqlite`, creates the single engine and role views, and returns ownership to the shell. `resume` is idempotent and covers both cold-start recovery and foreground resume. `dispose` cancels polling timers and subscriptions, closes stream controllers and the Drift database, and shuts down its database executor isolate.

If opening fails recoverably, the shell registers `Payjoin.unavailable(failure)` role views and does not register or invoke a lifecycle. Every unavailable role returns the captured typed failure without touching protocol, wallet, network, or database resources. This keeps unrelated wallet functionality available and keeps dependency registration complete without pretending that a partial engine exists.

Do not add `start`: opening constructs the engine, and `resume` starts or repairs unfinished protocol work. Do not add `pause` during extraction because the current implementation does not suspend Payjoin when the app backgrounds; adding it would change behavior.

Background locators must not call `openPayjoin` or `resume`. The current app has background execution disabled, and registration alone must not start a second protocol executor.

### Public operations

The target role interfaces are:

```dart
abstract interface class PayjoinSender {
  @useResult
  Future<Result<PayjoinSenderSession, PayjoinFailure>> start(
    StartPayjoinSender request,
  );

  @useResult
  Future<Result<PayjoinSession, PayjoinFailure>> broadcastOriginal(
    String sessionId,
  );
}

abstract interface class PayjoinReceiver {
  @useResult
  Future<Result<PayjoinReceiverSession, PayjoinFailure>> start(
    StartPayjoinReceiver request,
  );

  @useResult
  Future<Result<void, PayjoinFailure>> cancel(String sessionId);

  @useResult
  Future<Result<void, PayjoinFailure>> disableAll();
}

abstract interface class PayjoinSessions {
  @useResult
  Future<Result<PayjoinSession?, PayjoinFailure>> byId(String sessionId);

  @useResult
  Future<Result<List<PayjoinSession>, PayjoinFailure>> byTransactionId(
    String transactionId,
  );

  @useResult
  Future<Result<List<PayjoinSession>, PayjoinFailure>> list(
    PayjoinSessionFilter filter,
  );

  Stream<Result<PayjoinSession, PayjoinFailure>> watch({
    Set<String>? sessionIds,
  });

  @useResult
  Future<Result<Set<Outpoint>, PayjoinFailure>> reservedOutpoints();
}

abstract interface class PayjoinPolicyAccess {
  @useResult
  Future<Result<PayjoinPolicy, PayjoinFailure>> load();

  Stream<Result<PayjoinPolicy, PayjoinFailure>> watch();

  @useResult
  Future<Result<PayjoinPolicy, PayjoinFailure>> setEnabled(bool enabled);

  @useResult
  Future<Result<PayjoinPolicy, PayjoinFailure>> setMinimumAmount(
    Sats amount,
  );

  @useResult
  Future<Result<PayjoinPolicy, PayjoinFailure>> setSessionLifetime(
    Duration lifetime,
  );
}

abstract interface class PayjoinDiagnostics {
  @useResult
  Future<Result<PayjoinRelayHealth, PayjoinFailure>> relayHealth();
}
```

The exact request fields remain package-owned, typed values. `StartPayjoinSender` carries wallet ID, bitcoin network, BIP21 URI, unsigned original PSBT, amount, fee rate, and an optional caller-imposed expiry bound. `StartPayjoinReceiver` carries wallet ID, bitcoin network, address, optional amount, and an optional caller-imposed expiry bound.

`PayjoinSessionFilter` carries optional wallet ID and bitcoin network constraints plus `ongoingOnly`. `Outpoint` is the shared transaction-ID/vout value currently represented by `lib/core/wallet/domain/entities/outpoint.dart`; the first extraction commit moves that concept into primitives rather than inventing a Payjoin-specific duplicate.

The package resolves its stored policy when starting a session. A caller may shorten expiry for an order deadline, but cannot bypass package policy bounds. Sender signing moves behind `PayjoinWalletPort`; callers do not pre-sign merely because the old use-case did.

`reservedOutpoints` is public because `PrepareBitcoinSendUsecase` currently excludes UTXOs committed to ongoing Payjoins. It is a session capability, not a repository leak.

`byTransactionId` returns all matches because an in-app transfer can produce both a sender and receiver session for the same transaction. Feature use-cases decide which direction they need.

### Failures and results

Publish one Flutter-free sealed `PayjoinFailure extends Failure` family and return `Result<T, PayjoinFailure>` for every recoverable operation.

Include explicit variants for invalid input, unavailable package, unavailable wallet, unavailable relay, protocol rejection, session not found, invalid session transition, storage failure, migration failure, signing failure, broadcast failure, and unexpected infrastructure failure. Map foreign and shared-core failures into this package family at the boundary so consumers never cast or switch on infrastructure failures.

Keep developer detail in `logMessage`; never return it as user copy. Each consuming feature maps `PayjoinFailure` into its own failure family and translates that feature failure in presentation.

Streams emit typed failures rather than terminating with foreign datasource exceptions. Programmer errors remain uncaught and reach Sentry.

The first extraction commit imports the canonical `Failure` and `Result` definitions into `packages/primitives` before `bull_payjoin` is wired into features. Do not duplicate them in `bull_payjoin`.

### Policy ownership

Move these values from the root settings database into `payjoin.sqlite`:

- `enabled`, default `false`.
- `minimumAmount`, default 10,000 sats.
- `sessionLifetime`, default 24 hours.

`PayjoinPolicy` validates all minimum and maximum bounds at construction, so invalid policy cannot enter the engine. Policy persistence and stream notification live behind `payjoin.policy`.

When `setEnabled(false)` succeeds, the package persists the user intent first and then settles receiver sessions using the current `disableReceivers` semantics. Failure to settle is logged and retried by the next `resume`; it does not silently re-enable Payjoin.

The one-time `payjoin_disclaimer_shown` flag remains in the Settings feature's SharedPreferences repository because it records presentation history, not protocol policy. The Settings feature asks for consent and then calls its own use-case, which invokes `PayjoinPolicyAccess`.

### Ports and secret handling

The package defines capability ports; the shell supplies adapters from existing wallet, blockchain, transaction, labels, and storage components.

`PayjoinWalletPort` provides only the operations required to start and process sessions: sign a PSBT, obtain an ownership checker and PSBT processor for a wallet, and enumerate sanitized spendable UTXO candidates. It must not return a mnemonic, seed, xpriv, passphrase, `SeedModel`, `WalletModel`, or BDK model.

The current engine reconstructs a private wallet by reading mnemonic words in `_loadWallet`. The extraction must replace that with a wallet-owned signing/session capability before moving the engine. This is security-sensitive work: key material must remain inside the wallet/secrets boundary and must never enter package logs, DTOs, persisted rows, or long-lived facade state.

`PayjoinBlockchainPort` broadcasts finalized transactions and PSBTs for a typed bitcoin network. The root adapter owns Electrum server selection and fallback; the package does not import Electrum connection types.

`PayjoinTransactionPort` watches and actively refreshes transaction visibility by wallet ID and transaction ID. It supports the competing original-versus-Payjoin broadcast race without exposing wallet repository entities.

`PayjoinLabelsPort` records the package-owned metadata required after a session resolves. Its adapter calls the Labels feature's published facade; `bull_payjoin` never imports feature code.

`PayjoinLegacyDataPort` supplies one read-only migration snapshot from the upgraded root database. It contains package migration DTOs, not Drift rows. It is used only while opening an uninitialized `payjoin.sqlite` and is not retained by the engine.

`PayjoinLogPort` accepts structured events with privacy-safe session references. It must not accept arbitrary objects or raw session URIs, PSBTs, transactions, addresses, seeds, or key material.

Adapters live with the capability provider or in shell composition code. Do not create `lib/core/payjoin/adapters`; that would retain the module being removed and reverse ownership.

### Internal architecture

The package keeps one inward dependency chain:

```text
public role interfaces
  -> package use-cases / engine orchestration
    -> domain entities and repository interface
      -> repository implementation
        -> package-owned Drift and PDK datasources
        -> injected capability ports
```

The public library exports only the facade, role interfaces, lifecycle factory, request/filter types, session entities, policy, failures, health value, and required port contracts. It does not export repository interfaces, repository implementations, datasources, Drift database classes, rows, PDK models, mappers, or locator code.

The app composition root owns `get_it` registration. `bull_payjoin` exposes constructors and `openPayjoin`, not a `PayjoinLocator`; package source never imports, exports, or accepts a `get_it` type.

Suggested layout:

```text
packages/bull_payjoin/
  analysis_options.yaml
  pubspec.yaml
  lib/
    bull_payjoin.dart
    src/
      public/
        payjoin.dart
        payjoin_lifecycle.dart
        payjoin_sender.dart
        payjoin_receiver.dart
        payjoin_sessions.dart
        payjoin_policy_access.dart
        payjoin_diagnostics.dart
      domain/
        entities/
        ports/
        repositories/
        usecases/
        payjoin_failure.dart
      data/
        datasources/
        models/
        mappers/
        payjoin_repository_impl.dart
        payjoin_database.dart
      engine/
  test/
    domain/
    data/
    engine/
    migration/
```

Apply the repository's folder-count rule while implementing this outline: keep a role directly in its layer until a second file earns a subfolder.

## Database Ownership

### New database

Create `payjoin.sqlite`, owned and opened exclusively by `bull_payjoin`.

Schema version 1 contains:

- Sender sessions, preserving the current 14 persisted columns and `uri` primary key.
- Receiver sessions, preserving the current 17 persisted columns and `id` primary key.
- One policy row containing enabled, minimum amount, and session lifetime.
- A package migration ledger containing migration name, completion time, source schema version, sender count, receiver count, and verification digest.

The package owns later schema migrations and Drift schema snapshots. Root `SqliteDatabase` no longer changes when Payjoin evolves.

Open the database with `NativeDatabase.createInBackground` or an equivalent single-client Drift executor. Only the database runs on that isolate; the stateful protocol engine, timers, locks, ports, and PDK callbacks remain in one foreground engine instance. Close the database and executor through `PayjoinLifecycle.dispose`.

### Cutover order

Cold startup performs these steps in order:

1. Upgrade `bullbitcoin_sqlite.sqlite` through the root's existing schema migration path, currently to schema 14.
2. Build root-owned port adapters without starting Payjoin protocol work.
3. Call `openPayjoin` with the target path and `PayjoinLegacyDataPort`.
4. If `payjoin.sqlite` has no completed import marker, read the legacy snapshot while no Payjoin engine exists and no UI can write Payjoin state.
5. Validate every source row and policy value into package models before writing.
6. Insert sender sessions, receiver sessions, policy, and the migration marker in one target-database transaction.
7. Read the target rows back and compare row counts, primary-key sets, and a deterministic digest over every persisted field.
8. Commit only when verification succeeds; otherwise roll back the target transaction, leave the source untouched, return `PayjoinMigrationFailure`, and retry on the next launch.
9. Register public roles in `get_it` and call `PayjoinLifecycle.resume` only after migration succeeds.

There is no dual-write period. Quiescing the old engine before the snapshot is the write barrier.

The verification digest is SHA-256 over a canonical byte stream ordered by table discriminator and primary key. Every persisted field is encoded in schema order with a type tag, null marker, and length prefix; integer values use a fixed-width signed encoding, text uses UTF-8, and blobs use raw bytes. The source digest is calculated from validated migration DTOs and compared with a fresh target read inside the same target transaction. The migration-ledger row is excluded from the digest.

A process crash before the target transaction commits leaves no migration marker or partial imported rows, so the next cold launch repeats the import. A crash after commit sees the marker and verifies the committed target rather than importing again.

Using SQLite `ATTACH` is optional, not part of the public design. If used internally, remember that SQLite does not guarantee crash-atomic multi-database transactions when the main database uses WAL. The migration therefore treats the root database as read-only and makes only the target transaction authoritative.

### Failure mode and rollback

A failed migration must not start a partially initialized engine. The app continues with `Payjoin.unavailable(migrationFailure)` registered for the public roles and no `PayjoinLifecycle`; send and receive use-cases receive that typed failure rather than falling back through uninitialized dependencies. Status reports Payjoin as unavailable, the failure is logged without sensitive data, and the migration retries on the next cold launch.

The legacy tables and settings columns remain untouched for at least one release. Rolling back the app binary after new sessions have been written only to `payjoin.sqlite` is unsupported because an older binary cannot see those sessions. Release notes and operational rollback procedures must state this explicitly.

Drop legacy tables and columns only in a later contraction release after the migration has been observed in production and the supported downgrade window has closed.

## Consumer Migration

Every feature keeps its own use-case boundary:

```text
BLoC or Cubit -> feature use-case -> narrow bull_payjoin role
```

Existing feature use-cases that already orchestrate a flow inject the role directly; do not add a one-line wrapper around another use-case. Existing blocs and widgets that import Payjoin core use-cases receive a feature-owned use-case before the package cutover.

Consumer mapping:

| Consumer | Target dependency |
| --- | --- |
| Send, sell, pay | `PayjoinSender` and `PayjoinSessions` through their feature use-cases |
| Receive, buy | `PayjoinReceiver` and `PayjoinSessions` through their feature use-cases |
| Transactions | `PayjoinSessions`; sender fallback action uses `PayjoinSender` |
| Settings | `PayjoinPolicyAccess`; disclaimer remains Settings-owned |
| Status | `PayjoinDiagnostics` |
| Wallet send preparation | `PayjoinSessions.reservedOutpoints` |
| Shell lifecycle | `PayjoinLifecycle` only |

Transaction feature entities may reference published `PayjoinSession` types. They must not import package implementation files or map PDK/Drift types.

Update `FEATURES.md` when implementation changes dependencies. Payjoin becomes a shared package node, not a feature that depends directly on Labels or UTXO Management. The shell adapters depend on both sides of those ports; `bull_payjoin` itself depends only on its published port contracts and leaf packages.

## Build and Tooling

The package needs direct dependencies for the APIs it imports, expected to include `payjoin`, `drift`, `dio`, `synchronized`, `crypto`, `meta`, serialization annotations, and the shared primitives package. Keep the exact list driven by imports after extraction.

The upstream `payjoin` dependency uses Rust Native Assets. Moving it to a transitive dependency of `bull_payjoin` does not remove the native build; Android, iOS, Linux, clean-container, and reproducibility builds must all be rerun.

Build Runner and Drift generation are package-scoped. Replace the root-only generator invocation with a canonical workspace command based on the verified Melos filter `fvm dart run melos exec --depends-on=build_runner -- fvm dart run build_runner build --force-jit --delete-conflicting-outputs`. Extend `make drift-migrations` similarly for packages that depend on `drift_dev`, while preserving generated schema snapshots with their owning package.

Update `make unit-test` so Flutter packages run `fvm flutter test` and pure-Dart packages such as `bull_payjoin` run `fvm dart test`; do not force a Flutter SDK dependency into `bull_payjoin` merely to fit the current loop.

Use only the shared root `pubspec.lock`, per current Pub workspace behavior. `make deps`, `make bootstrap`, `make analyze`, `make checks`, `make unit-test`, `make android`, and the reproducibility build must cover `bull_payjoin` before cutover.

Verify that whole-workspace analysis and test discovery actually include the package instead of relying on the current comments, several of which still describe an empty workspace even though `bull_ui` and `bull_ui_catalogue` are members.

## Test Plan

Before moving behavior, retain or add characterization tests for:

- Sender and receiver creation.
- PDK request and proposal processing.
- Original-versus-Payjoin broadcast races.
- Manual original broadcast guards.
- Expiry, abort, completion, and restart recovery.
- Per-session serialization and cross-session UTXO reservation.
- Receiver disable and cancellation semantics.
- Relay failover and timeout handling.
- Privacy-safe logging with no URI, PSBT, address, transaction bytes, mnemonic, seed, xpriv, or passphrase.

Package tests must cover:

- Entity and policy invariants.
- Every `PayjoinFailure` mapping at repository boundaries.
- Each role through faked ports.
- Unavailable role views return the original typed failure and perform no side effects.
- One engine shared by all role views.
- Idempotent concurrent `resume` calls.
- Complete `dispose`, including timers, subscriptions, streams, PDK resources, database connection, and executor isolate.
- Fresh database creation.
- Migration from a schema-14 legacy fixture with zero, sender-only, receiver-only, mixed, ongoing, completed, aborted, and expired sessions.
- Migration rollback after malformed rows, write failure, and digest mismatch.
- Retry after a failed migration.
- No re-import after a successful marker.
- Root source rows unchanged by both success and failure.
- Root integration tests for send, receive, transaction hydration, settings, service status, and app foreground resume.

The migration fixture must be generated from the real root schema snapshot rather than a hand-written approximation.

Privacy tests inject a recording `PayjoinLogPort`, exercise success and every mapped failure path with sentinel secret values, and assert that neither structured fields nor rendered messages contain those sentinels. The root logging adapter accepts only the package's redacted structured event type, so it cannot forward arbitrary exception objects to logs or Sentry.

## Delivery Sequence

Use one branch, `payjoin-package-infrastructure`, and one final PR targeting `develop`. The branch starts at `785310254`, so the final review includes the unreviewed Reliability and Exchange UX commit ranges followed by the extraction phases below.

Before the first extraction commit, merge the current `origin/develop` into this branch without rewriting the already-shared Payjoin history. Do not squash the branch. Every extraction commit must compile and pass its relevant tests on its own, and the PR description must give reviewers this exact reading order.

### Phase 1: existing functional baseline

Review the Reliability and Exchange UX commits already consolidated before `785310254` as functional changes. Do not hide fixes found in this review inside a movement commit. Because those source commits are already merged into a shared integration branch, preserve that history and add any required correction as an explicit atomic commit before the extraction phases.

### Phase 2: shared primitives

Import only the `packages/primitives` slice required by workspace packages, add shared `Outpoint`, update workspace configuration and the root lockfile, and preserve its tests.

Suggested commit: `feat(core): add shared primitives package`

### Phase 3: characterize the current engine

Add missing behavior, lifecycle, race, privacy, and schema-14 fixture tests around the current implementation without changing production behavior.

Suggested commit: `test(payjoin): lock engine and migration behavior`

### Phase 4: consolidate generic success UI

Promote `SuccessScreenScaffold` to `BullSuccessScreen`, adapt Buy/Sell/Pay, preserve feature-owned behavior, and add `bull_ui` widget tests and catalogue use cases.

Suggested commit: `refactor(ui): promote shared success screen`

### Phase 5: publish the package contract

Add `packages/bull_payjoin` with the facade, role interfaces, lifecycle contract, package domain entities, policy invariants, failures, ports, curated export, and tests. Add the workspace and root dependency entries with the shared root lockfile update. Adapt the legacy implementation behind the new roles and migrate consumers to feature-owned use-cases and narrow role injection, while storage and protocol execution still use the old engine.

The temporary adapter is `LegacyPayjoinRoles` under the existing `lib/core/payjoin/` module. It maps package request/session/result types to the current root Payjoin use-cases and `PayjoinRepository`; it does not expose the repository publicly, write a second database, or create another engine. It must be deleted by the cutover phase and must not become a supported compatibility API.

Suggested commits:

- `feat(payjoin): publish workspace package contract`
- `refactor(payjoin): route consumers through package roles`

### Phase 6: seal wallet key operations

Add a wallet-owned capability that produces the ownership checks and PSBT processing operations required by PDK without returning mnemonic words, seed data, passphrases, xprivs, or wallet data models. Switch the current root Payjoin engine to this capability while preserving protocol behavior and retaining the characterization tests.

This is a pure security-boundary refactor and requires an explicit wallet/secrets review inside the final PR.

Suggested commit: `refactor(wallet): seal payjoin signing capability`

### Phase 7: implement package persistence and engine

Add package-owned Drift schema, policy storage, legacy importer, repository implementation, PDK datasource, one shared engine, lifecycle implementation, and root capability adapters. Keep the implementation unselected by production wiring until its package and migration tests pass.

Provider-owned adapters live beside their providers, for example wallet and transaction adapters under their existing core domains and the legacy snapshot adapter under root storage. The Labels bridge lives in shell composition code because it joins a package port to a feature facade; it is not part of `bull_payjoin` or the Labels public contract.

- `feat(payjoin): add package-owned persistence` with schema and migration tests.
- `refactor(payjoin): move protocol engine behind ports` with engine tests.
- `test(payjoin): verify cross-cutting recovery and migration` for scenarios spanning both implementations.

These commits consume the sealed wallet capability and do not handle raw key material.

### Phase 8: cut over atomically

Switch foreground composition to `openPayjoin`, run the verified one-time import, register narrow roles, call lifecycle resume from startup and app resume, and use the package implementation for all consumers. Remove `LegacyPayjoinRoles` in the same commit so there is one active engine and one write path.

Do not delete legacy source tables or settings columns.

Suggested commit: `refactor(payjoin): cut over to package engine`

### Phase 9: remove legacy implementation

Delete `lib/core/payjoin/`, remove obsolete root Payjoin use-cases and locator wiring, remove Payjoin policy from root Settings entities and repositories after all reads use the package, and update architecture and dependency documentation.

Keep minimal legacy table declarations or migration snapshot code under root storage only where the old database schema still requires them. Name them explicitly as legacy and prevent production writes.

Suggested commit: `refactor(payjoin): remove legacy core implementation`

### Later release: contract old storage

After production migration evidence and the downgrade window permit it, remove old Payjoin tables and settings columns through a root database migration.

Suggested commit: `refactor(storage): drop migrated payjoin schema`

## Acceptance Criteria

- `packages/bull_payjoin` is a workspace member and the root app depends on `bull_payjoin`, not directly on upstream `payjoin`.
- `packages/primitives` supplies the single canonical `Failure`, `Result`, `BitcoinNetwork`, and `Outpoint` definitions used across package boundaries.
- `lib/core/payjoin/` and `lib/features/payjoin/` do not exist.
- No package source imports `package:bb_mobile`, Flutter, a feature package, `get_it`, root Drift rows, wallet models, seed models, or Electrum connection types.
- No BLoC, Cubit, or widget calls `Payjoin` or a package role directly; feature use-cases inject narrow roles, and repositories or datasources do not depend on the facade.
- The shell alone owns `PayjoinLifecycle`.
- One engine instance owns every session lock, timer, watcher, stream, and PDK subscription.
- `payjoin.sqlite` owns sessions, policy, schema versioning, and migration ledger.
- Migration is verified, retryable, source-preserving, and performed before protocol resume, with no dual writes.
- Recoverable operations return typed results and user-facing layers never display developer messages.
- Mnemonic, seed, xpriv, passphrase, raw PSBT, raw transaction, address, and full sender URI never enter logs or Sentry.
- Existing Payjoin behavior remains covered by characterization and integration tests.
- `BullAsyncStatus` and `BullSuccessScreen` are domain-agnostic `bull_ui` components; Buy/Sell/Pay retain all business state, routing, localization, timers, assets, and actions.
- `lib/core/widgets/success_screen_scaffold.dart` no longer exists, and no additional Payjoin/Exchange UI migrated into `bull_ui`.
- `make deps`, `make bootstrap`, `make build-runner`, `make checks`, `make android`, and the reproducibility build pass with the package.
- `ARCHITECTURE.md`, `FEATURES.md`, workspace comments, and tooling documentation describe the actual package graph and shared-lockfile behavior.

## Rejected Alternatives

### Static facade

Rejected because it hides dependencies, couples calls to global state, weakens test substitution, and makes ownership of timers, subscriptions, database connections, and disposal unclear.

### One flat public service

Rejected because sender, receiver, session query, policy, diagnostics, and lifecycle consumers have materially different capabilities. A flat header interface would force every test double and consumer to depend on unrelated operations.

### Independent sender and receiver engines

Rejected because both roles must share persistence, session locks, UTXO reservation, broadcast races, watcher streams, and teardown. Public role interfaces are views over one engine, not separate runtimes.

### Lifecycle under sessions

Rejected because app resume and disposal govern process resources rather than a business session. Putting them under `sessions` would expose shell ownership to ordinary feature code.

### Public repository and datasources

Rejected because they expose implementation vocabulary and allow callers to bypass failure mapping, policy, invariants, and lifecycle control.

### Root-owned Payjoin database or policy

Rejected because it leaves the package dependent on app schema and settings internals, preventing independent evolution and preserving the current boundary problem.

### Squashed big-bang extraction

Rejected because one undifferentiated diff would combine contract design, consumer rewiring, key-handling changes, protocol movement, generated Drift code, data migration, Native Assets, and cleanup. The approved single PR preserves atomic commits and explicit review phases instead of squashing those concerns together.

## Research Basis

Sources were checked on 2026-07-30:

- Flutter, "Communicating between layers": constructor injection and explicit component communication, https://docs.flutter.dev/app-architecture/case-study/dependency-injection
- Dart, "Effective Dart: Design": consistent vocabulary, capability-readable APIs, private declarations, and controlled interface implementation, https://dart.dev/effective-dart/design
- Dart, "Pub workspaces": one shared package resolution and root lockfile; member lockfiles are deleted, page updated 2026-05-15, https://dart.dev/tools/pub/workspaces
- Martin Fowler, "Role Interface": define interfaces around actual supplier-consumer collaborations rather than mirroring one large implementation, https://martinfowler.com/bliki/RoleInterface.html
- Martin Fowler, "Service Layer": define an application boundary through available operations while coordinating internal responses, https://martinfowler.com/eaaCatalog/serviceLayer.html
- Drift, "Isolates": one logical database executor, synchronized streams, and explicit shutdown semantics, https://drift.simonbinder.eu/isolates/
- Drift, "Migrations": schema migration and generated migration support, https://drift.simonbinder.eu/migrations/
- Drift, "Testing migrations": generated schema fixtures and migration verification, https://drift.simonbinder.eu/migrations/tests/
- SQLite, "ATTACH DATABASE": attached-database transaction caveat with WAL, https://sqlite.org/lang_attach.html
- SQLite, "Write-Ahead Logging": WAL concurrency and durability properties, https://sqlite.org/wal.html
