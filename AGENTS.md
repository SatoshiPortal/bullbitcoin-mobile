# AGENTS.md

Instructions for AI coding agents working in this repo. Cross-tool standard ([agents.md](https://agents.md/)) — read by Cursor, Codex, Copilot, Jules, Devin, Factory, Aider, Zed, recent Claude Code, and others. If you use a tool that only reads `CLAUDE.md`, create a one-line local `CLAUDE.md` containing `See @AGENTS.md` (Claude Code resolves `@` imports). Not committed — `CLAUDE.md` is gitignored so each contributor sets it up if needed.

## Project

Bull Bitcoin Mobile: self-custodial Bitcoin + Liquid + Lightning wallet. Flutter/Dart, BLoC, Drift/SQLite, GoRouter, get_it DI. See [README.md](README.md) for product details.

**Repo doc map:** [README.md](README.md) = product · [ARCHITECTURE.md](ARCHITECTURE.md) = layer model & design rules (read its "Entry points & code tour") · **AGENTS.md** (this file) = toolchain, conventions, commit/test rules · [FEATURES.md](FEATURES.md) = cross-feature dependency graph.

**Composition root** (where to wire a new feature): `lib/main.dart` (`Bull.init()` → `initLocator()` → `runApp`) → `lib/locator.dart` (get_it; `AppLocator.setup` registers core, then every `<Feature>Locator.setup`) → `lib/router.dart` (GoRouter; `AppRouter.router` spreads each `<Feature>Router`'s routes). A new feature is added in those last two files.

## Toolchain — non-negotiable

- **Always `fvm flutter` / `fvm dart`.** Never bare `flutter`/`dart`. The pinned SDK lives in [`.fvmrc`](.fvmrc); using a global SDK silently breaks builds.
- **Use the makefile.** Don't reinvent commands:
  - `make deps` — `fvm flutter pub get --enforce-lockfile`
  - `make analyze` — `fvm flutter analyze --fatal-warnings --fatal-infos` (matches CI; same check the pre-commit hook runs)
  - `make bootstrap` — melos workspace bootstrap (wraps `fvm dart run melos bootstrap`)
  - `make build-runner` — codegen (freezed, json_serializable, drift, flutter_gen)
  - `make translations` — `fvm flutter gen-l10n`
  - `make setup` — full first-time setup (clean + deps + build-runner + translations + hooks + ios pods on macOS)
  - `make unit-test` / `make integration-test` / `make test`
  - `make drift-migrations` — after changing Drift schema
  - `make android` / `make android release` — reproducible build
  - `make android beta` — beta tester channel APK (`.beta` applicationId, installs alongside production)
  - `make verify` — verify a built APK matches a published release
  - `make build-runner-watch` — codegen in watch mode during dev
- **Analyze the whole project, never specific files.** `fvm flutter analyze` (no path arg). CI runs `--fatal-warnings --fatal-infos` ([analyze_and_test.yml](.github/workflows/analyze_and_test.yml)) — match it locally.
- **`fvm dart fix --dry-run` must print `Nothing to fix!`** before commit. If not, run `fvm dart fix --apply` and stage the result.
- **Pre-commit hook is the floor.** It runs analyze + dart fix dry-run ([`.git_hooks/pre-commit`](.git_hooks/pre-commit)). **Never `--no-verify`.** If it fails, fix the cause.

## Monorepo / melos

The repo is migrating incrementally to a [melos](https://melos.invertase.dev/) pub-workspace. Today the Flutter app is a single package at the repo root, kept there via `useRootAsPackage: true` in the `melos:` block of [`pubspec.yaml`](pubspec.yaml). There are no workspace members yet, so melos is a skeleton — the makefile and build chain behave exactly as before.

- **Run melos through the makefile** (`make bootstrap`), which wraps `fvm dart run melos` so the pinned SDK ([`.fvmrc`](.fvmrc)) is used. Never type bare `melos` (wrong SDK). For melos subcommands without a make target yet, use `fvm dart run melos <cmd>` — and add a make wrapper if it becomes routine.
- **The makefile stays canonical** for daily commands. melos does not replace it: `make deps` is still `fvm flutter pub get --enforce-lockfile`, and the reproducible build chain ([Containerfile.app](Containerfile.app), [build-android.yml](.github/workflows/build-android.yml)) does not run melos. melos is a `dev_dependency` only — never compiled into the app, so the reproducible APK is unaffected.
- **`packages/` and `features/` are reserved homes** for the migration (exception to rule #14 below): pure-Dart shared-foundation packages in `packages/` (shared domain like `wallet`/`secrets` + infrastructure like `storage`/`electrum`, no Flutter UI — `packages/` holds the shared foundation, with `lib/core`'s infra-only spirit per rule #7 preserved for the infra packages); Flutter feature packages (`send`, `receive`, `buy`, `sell`, …) mounted by the root shell in `features/`. A `packages/` member may depend on Flutter only to own a sealed UI component (e.g. `secrets`' `MnemonicView`, which renders the mnemonic without exposing it). As code is extracted, each new package gets `resolution: workspace` and is added to a `workspace:` key in the root pubspec; the root keeps `useRootAsPackage: true` (this combination is supported — see melos PR #927). See ARCHITECTURE.md "Monorepo Migration" for the full layout and the sealed-UI / encapsulation rules.
- **When the first real member lands**, re-verify that `fvm flutter analyze` (and the pre-commit hook) still cover all members in one pass. Pub workspaces share a single analyzer context, so they should — confirm rather than assume. Also note: `enforceLockfile: true` makes `melos bootstrap` pass `--enforce-lockfile` to every member, which fails for a member that has no committed `pubspec.lock` — commit each member's lock, or bootstrap with `--no-enforce-lockfile` until locks exist.

## Architecture — enforce, don't drift

Read [ARCHITECTURE.md](ARCHITECTURE.md) ("How the codebase actually looks today" + "The architecture we tend toward") and [FEATURES.md](FEATURES.md) before adding or moving code. **The repo is in active migration.** Census (2026-06, 48 features): the dominant shape is `ui → bloc → usecase → repository → datasource` with most shared data + domain in `lib/core/<domain>` (≈30 domains, ≈26 repositories) and features mostly presentation + ui (bloc/cubit in ≈44); ≈21 features carry use-cases; ≈6 went fuller hexagonal (`application/` + `adapters/` + `frameworks/` + `interface_adapters/`); `public/` and `watchers/` are barely used (≈1 each). The target below is what new code must follow. Existing code may violate these rules — do not replicate violations, but don't refactor unrelated legacy in the same PR either.

Some rules below are canonical (textbook Clean/Hex Arch), others are deliberate project conventions. Both are binding here, but knowing which is which helps when an external source contradicts a rule — the project rules win inside this repo, but cite the canonical source if the conversation moves to *why*. Project rules are explicitly labeled.

Hard rules:

1. **Feature isolation — facade is our chosen pattern.** Modular Flutter has several valid options (facade, abstract use-case interfaces, event bus, mediator); this codebase picks facade. **Target location** (per ARCHITECTURE.md): `<feature>/public/<feature>_facade.dart`. **Current legacy** (e.g. [`labels_facade.dart`](lib/features/labels/labels_facade.dart)): facade at feature root. New facades use the target location; don't move legacy ones in unrelated PRs. Never import another feature's internals (`domain/`, `data/`, `presentation/`) — the `public/` facade is the only importable surface. **The facade *is* the interface** — a concrete class, not an `abstract interface class`; its method surface + `export` block are the contract (add an abstract interface only for DIP-to-break-a-cycle or test mocking). **It returns only the feature's published types** (the entity itself when clean and stable, else a dedicated public DTO + mapper as `labels` does) — **never** a `data/models/` model, an `application/`-internal type, or another feature's entity, and the return type must be in the `export` block. Consumers wrap a facade call in **their own** use-case (rule #4). See ARCHITECTURE.md "The facade: a feature's public contract".
2. **Layer direction — one chain, always.** `ui → presentation (bloc/cubit) → usecase (domain) → repository (domain interface → data impl) → datasource (data)`. **A bloc never imports a repository or a datasource** — it always goes through a use-case, the testable seam where data-layer errors are mapped to feature errors. **Use-cases are always present but stay thin: orchestration only.** Put each kind of logic in its home — **invariants in domain entities/value objects; data-shaping (mapping, aggregation, caching) in the repository; orchestration in the use-case**. Pushing data-shaping or invariants into a use-case is the "fat use-case" smell — move it down. The inward-only dependency rule is [hexagonal-canonical](https://alistair.cockburn.us/hexagonal-architecture); the MVVM-spine + repository is the official [Flutter guide](https://docs.flutter.dev/app-architecture/recommendations). See ARCHITECTURE.md "The architecture we tend toward".
3. **Watchers go through use cases**, not repositories. `watcher → use case → repository`.
4. **BLoCs are thin — in our architecture.** No orchestration, no business decisions, no complex transforms; those live in use cases. (Note: [bloclibrary.dev](https://bloclibrary.dev/architecture/) treats the bloc layer itself as the business-logic layer above repositories — our "BLoC is thin, use case below it" stance is a deliberate Clean-Arch refinement, not bloclibrary canon.) **Project convention**: never call another feature's facade directly from a BLoC — wrap it in your own feature's use case (in `domain/usecases/`), and the BLoC calls that wrapper. This is the cure for "business logic in presentation" that ARCHITECTURE.md flags as the most common pitfall.
5. **Local widget state stays in `StatefulWidget`.** BLoC/Cubit is for business state only — what other layers care about. Form-field focus, animation controllers, expanded/collapsed panels, scroll positions: keep them in widget state. Mixing the two makes BLoC tests flaky and bloats state classes.
6. **Repository: abstract interface in `domain/`, impl in `data/` — don't over-abstract the rest.** Declare the contract as `abstract interface class <Noun>Repository` in `domain/repositories/<noun>_repository.dart` (the single `repositories/` folder); put the implementation in `data/<noun>_repository_impl.dart` next to its datasources — **no second `repositories/` folder**. A datasource wraps one external system and is a **private member** of its repository (bloc/UI can't reach it). One repository is enough for trivial CRUD; add a separate datasource only for real transformation, multiple backends, or clear logic to separate — two layers that forward-call each other are noise. **Boundary rule (never bends):** a repository's public signatures — returns **and** params — use only domain types (entities, value objects, `Result<Entity, …>`). Wire models, library types (BDK `LocalUtxo`, LWK, a Drift row), JSON `Map`s and DTOs never cross the repository boundary — they stay inside `data/`. *(Legacy leak, don't replicate: `WalletAddressRepository` takes a `WalletModel` param — a `data/` model in a `domain/` contract.)* **Entity and model are always two separate types** (entity in `domain/entities/`, wire/persistence model in `data/models/`, mapper between) — this is the boundary above, not over-abstraction, so never collapse it into one class even when they look identical. The entity is **self-validating** (invariants in the constructor/factory; an invalid instance can't exist) and carries **no** serialization; the model is **pure data** (serialization only, no rules). **Cap is two types per record** — the five-types-per-record pattern (entity / value-object / primitive / request-DTO / response-DTO + a mapper between each) is verbosity the Flutter team flags as *Conditional* ("separate models adds verbosity… Use in large apps", [recommendations](https://docs.flutter.dev/app-architecture/recommendations)); collapse *that*. Value objects are for correctness-critical primitives (amount/sats, address, fee rate), not every field.
7. **`/lib/core` is infrastructure only.** No feature/business logic. Generic primitives, drivers, helpers.
8. **Shared value objects go in `lib/core/primitives/`** (planned per [FEATURES.md](FEATURES.md) — folder doesn't exist yet at audit time, and `Secret`/`Address`/`Amount`/`Fingerprint` are not yet extracted as primitives). When you create a value object that more than one feature would reasonably use, put it in `lib/core/primitives/` from the start — that's how the primitives layer gets built. Before creating one, grep `lib/` for an existing class with the same intent.
9. **Prefer rich domain models** — methods that enforce invariants, not anemic DTOs mirroring DB rows. (Note: [Fowler's anemic-domain anti-pattern](https://www.martinfowler.com/bliki/AnemicDomainModel.html) is widely cited but [not universal](https://blog.inf.ed.ac.uk/sapm/2014/02/04/the-anaemic-domain-model-is-no-anti-pattern-its-a-solid-design/). This is our preference, aligned with ARCHITECTURE.md's "Anemic Domain Models" pitfall.)
10. **No raw colors.** Always pull from the theme. If the user describes a color in plain language, pick the closest theme color that works in both light and dark mode. Don't edit theme files unprompted.
11. **Failures — one sealed family per feature, `*Failure` not `*Error`.** Three words, kept apart: **`Exception`** = thrown infra (data layer, caught at the boundary); **`Error`** = a `dart:core` programmer bug, never caught (→ Sentry); **`Failure`** = a modeled, recoverable **value** in `domain/`. Define a sealed `<Feature>Failure extends Failure` in `domain/<feature>_failure.dart`, **Flutter-free**; cross-cutting modes (network, storage-locked, not-found, timeout, auth, device, insufficient-funds) come from the shared `sealed CoreFailure` in `lib/core/failures/` (alongside the `Failure` base; the legacy `lib/core/errors/` is the graveyard until emptied). Map foreign errors at the boundary; never leak another layer's or feature's type. **Translation is a presentation extension, not a method on the failure:** `presentation/<feature>_failure_l10n.dart` exposes `toTranslated(BuildContext)` — the only place `context.loc` / `flutter` touches a failure (keeps `domain/`+`data/` Flutter-free); the `sealed` switch makes a missing user message a compile error. **The end user never sees a dev string:** the catch-all variant returns a **generic localized** message (`oopsSomethingWentWrong`), never the raw `logMessage` (logged at the boundary, for us only) — `unexpected: (m) => m` leaks dev detail. **Propagation:** repositories return `Result<T, F extends Failure>` (variants `Ok`/`Err`, generic over `F` so consumers never cast, `@useResult`; helpers `fold`/`map`/`mapErr`); `throw` only for `dart:core` bugs ([Flutter Result](https://docs.flutter.dev/app-architecture/design-patterns/result)). The **repository** is the one `try/catch` boundary (or the feature **use-case** when wrapping a shared core repo that still throws); use-cases forward/compose `Result`s; the bloc `switch`es and holds the typed `<Feature>Failure` in state (no `BuildContext` in `presentation/` logic); the UI renders `failure.toTranslated(context)`. **Migration (#1895) is sanctioned and staged** — bring a feature fully in line when you touch it, one feature per PR. **Legacy (don't replicate, converge per-feature):** `BullException` + hardcoded English; `<Feature>Error` naming; `toTranslated` *on* the error; per-layer splits (`domain_errors.dart`/`application_errors.dart`/…); `fund_exchange`'s feature-prefixed singular.
12. **Acyclic feature graph.** Check [FEATURES.md](FEATURES.md) before adding a dependency.
13. **Keep the dependency graph live.** Any PR that adds a feature, removes a feature, or changes which other features it consumes via `public/` facades **must** update the mermaid graph in [FEATURES.md](FEATURES.md) in the same commit. The graph is documentation only if it matches the code — if you change one without the other, both become useless.
14. **Folders justify their existence — files don't justify folders.** A tiny piece of code is one file with a role suffix, not a folder of one file:
    - One use case → `<feature>/domain/<verb>_<noun>_usecase.dart`. Don't create `domain/usecases/` for a single file.
    - One entity → `<feature>/domain/<noun>.dart`. Don't create `domain/entities/` for a single file.
    - One datasource → `<feature>/data/<noun>_datasource.dart`. Don't create `data/datasources/` for a single file.

    Create the folder the moment a **second** file of that kind appears (or you know it's imminent in the same PR). Don't pre-create empty folders or use `.gitkeep`. Suffix carries the role; path carries the layer.

    **Exception (melos migration):** `packages/` and `features/` are intentionally pre-created with `.gitkeep` as reserved workspace homes for the in-progress monorepo migration — do not remove them or treat them as a rule-#14 violation. See the Monorepo / melos section.

15. **Enforce with the compiler, not hope.** Repository contracts → `abstract interface class` (forbids `extends`, forces `implements`); lock finer capabilities with `@Deprecated.implement()` / `.instantiate()` / `.extend()` (Dart 3.10+). Failure families and multi-case states → `sealed` (a missing `switch` case is a compile error). `Result`-returning repo methods → annotate `@useResult` (`package:meta`) so a discarded result warns. Cross-feature and `data/`-from-`presentation/` bans → a rule in the first-party analyzer plugin system (Dart 3.10+, the supported successor to `custom_lint`); under melos, package boundaries + the `implementation_imports` lint make them hard errors. All available in the current toolchain (Flutter 3.41/3.44 bundle Dart 3.11/3.12) — no point-release dependency; nothing new in 3.41/3.44 is required.

When a request would break these rules, explain why and propose a compliant alternative. Don't silently comply.

When you **work in** a feature, file, or folder that already violates these rules (legacy, a drifted hexagonal module, a leaked boundary), don't silently work around it and don't quietly copy it. **Flag it and offer a fix:** name the specific rule it breaks and propose a **scoped refactoring** to bring it into line — as its **own** atomic commit/PR, separate from the task at hand. Then let the developer decide: take it now, defer it, or skip it. Never fold an opportunistic refactor into an unrelated change (that breaks atomic commits). This is the "leave it cleaner than you found it" rule from [ARCHITECTURE.md](ARCHITECTURE.md)'s intro, kept compatible with atomic commits — surface the opportunity, don't force it.

## Naming conventions

Codified from a sweep of the actual codebase. ARCHITECTURE.md is silent on most of these; the rules below reflect what the dominant code already does. Where two conventions exist, the recommendation is the more common one — migrate toward it, don't replicate the minority.

**Folders** (inside a feature):

| Folder | Convention | Notes |
|---|---|---|
| `domain/entities/` | plural | rich models + value objects |
| `domain/repositories/` | plural | the single `repositories/` folder — **abstract** interfaces (contracts) |
| `domain/usecases/` | plural, no underscore | the canonical use-case home (~80% already here) |
| `data/datasources/` | plural, no underscore | not `data_sources/`; one external system each |
| `data/models/` | plural | wire/persistence model — **1 per entity, always separate from the entity** |
| `data/mappers/` | plural | model ↔ entity; a file only once it earns one (rule #14) |
| `data/` (repo impl) | — | `<noun>_repository_impl.dart` lives directly here — no `data/repositories/` folder |
| `presentation/` | — | bloc/cubit + state + event |
| `ui/screens/`, `ui/widgets/` | plural | |
| `public/` | — | facade lives directly inside |
| `watchers/` | plural, optional | drives use-cases, never repositories |

> Deprecated — converge away (see ARCHITECTURE.md "Convergence"): `application/`, `adapters/`, `interface_adapters/`, `frameworks/`.

**Files** — `snake_case`, singular suffix:

| Kind | Pattern | Example |
|---|---|---|
| Use case | `<verb>_<noun>_usecase.dart` | `broadcast_bitcoin_transaction_usecase.dart` |
| Repository interface (abstract) | `<noun>_repository.dart` in `domain/repositories/` | `bitcoin_wallet_repository.dart` |
| Repository impl | `<noun>_repository_impl.dart` **or** `<tech>_<noun>_repository.dart`, in `data/` | `exchange_rate_repository_impl.dart`, `drift_electrum_server_repository.dart` |
| Datasource | `<noun>_datasource.dart` **or** `<tech>_<noun>_datasource.dart`, in `data/datasources/` | `electrum_remote_datasource.dart`, `bdk_wallet_datasource.dart` |
| Entity / value object | `<noun>.dart` | `wallet.dart`, `auto_swap.dart` |
| Model (wire/persistence) | `<noun>_model.dart` in `data/models/` | `wallet_utxo_model.dart` |
| Mapper | `<noun>_mapper.dart` in `data/mappers/` | `wallet_utxo_mapper.dart` |
| Bloc | `<feature>_bloc.dart` | `send_bloc.dart` |
| Cubit | `<feature>_cubit.dart` | `settings_cubit.dart` |
| State | `<feature>_state.dart` | `send_state.dart` |
| Event | `<feature>_event.dart` | `send_event.dart` |
| Facade | `<feature>_facade.dart` | `labels_facade.dart` |
| Locator | `<feature>_locator.dart` | `wallet_locator.dart` |
| Failure (family) | `<feature>_failure.dart` (domain) + `<feature>_failure_l10n.dart` (presentation) | per rule #11 |

**Classes** — `PascalCase`, matching local quirks:

- **Use cases**: `<Verb><Noun>Usecase` — **lowercase 'case'**, never `UseCase`. Codebase-wide convention (`GetSettingsUsecase`, `UpdateTorSettingsUsecase`, `BroadcastBitcoinTransactionUsecase`). Single public entry method **`execute(...)`** (206 of 209 use-cases; never `call`).
- **Datasources**: `<Name>Datasource` — **lowercase 's'**, never `DataSource`. Codebase-wide (`BdkWalletDatasource`, `BoltzDatasource`).
- **Repositories**: abstract interface = `<Name>Repository` (`abstract interface class`, in `domain/repositories/`); concrete impl = `<Name>RepositoryImpl` or `<Tech><Name>Repository` (in `data/`). Pick the technology prefix when the backing tech is meaningful (Drift, Bdk, Boltz, GoogleDrive, Bullbitcoin); use `Impl` when the technology label would be awkward.
- **Entities & value objects**: bare noun, **no `Entity` suffix** (`Wallet`, `WalletUtxo`, `TransactionOutput`). Two legacy outliers (`BitboxDeviceEntity`, `LedgerDeviceEntity`) — don't replicate.
- **Models (wire/persistence)**: `<Noun>Model` (`WalletUtxoModel`) — in `data/models/`, freezed; serialization only, never crosses the repository boundary (rule #6).
- **Mappers**: `<Noun>Mapper` (`WalletUtxoMapper`) — in `data/mappers/`; translates model ↔ entity.
- **Non-repository domain interfaces**: `<Name>Port` (`BlockchainPort`, `ElectrumConnectivityPort`) — a capability abstraction that is not a repository; lives in `domain/`. Repository interfaces use `<Name>Repository`, never `Port`. (The `Port` *suffix* stays for these; only the hexagonal *folders* `application/`/`adapters/`/`frameworks/` are deprecated.)
- **Bloc/Cubit**: `<Feature>Bloc` / `<Feature>Cubit` (`SendBloc`, `SettingsCubit`).
- **State / Event**: `<Feature>State` / `<Feature>Event`, sealed with freezed when there are multiple cases.
- **Facade**: `<Feature>Facade` (`LabelsFacade`).
- **Watcher** (when introduced): `<Subject>Watcher`.
- **Failure**: one sealed `<Feature>Failure` family per feature in `domain/<feature>_failure.dart` (base `Failure`); never `<Feature>Error` — `Error` is reserved for `dart:core` bugs. Translation extension `<Feature>FailureL10n` in `presentation/`. See rule #11.

When the same role exists with two names in the codebase, use the dominant one and flag the outlier as legacy. Don't rename outliers in unrelated PRs — that breaks atomic commits.

### Member ordering

Inside a class, declare members in this order, with a blank line between each group:

1. **Instance fields** — the object's state. Reading these first tells you *what the thing is*.
2. **Constructor(s)** — how it's built, on top of the fields you just read.
3. **Methods** — its behaviour, including `@override`s.

```dart
class Amount {
  final BigInt sats;

  Amount(this.sats) {
    if (sats < BigInt.zero) throw ArgumentError('Amount cannot be negative');
  }

  bool get isDust => sats < BigInt.from(546);
}
```

This is fields-first on purpose: our domain, value, and error types are defined by their state, so surfacing it first reads most naturally (and matches the field-first habit of most other languages). It is a soft convention — the analyzer does not enforce member order, so keep it consistent by hand and in review.

**Do not enable the `sort_constructors_first` lint.** It enforces the *opposite* order (constructor before fields); turning it on would fight this convention and churn every class. Widgets, whose constructor is effectively their public API, may keep the constructor first if that reads better there — don't reformat existing widgets to satisfy this rule.

## UI Kit — reuse first, build the kit as you go

The codebase is migrating toward a real UI Kit. The skeleton already lives in [`lib/core/widgets/`](lib/core/widgets/) (`buttons/`, `cards/`, `inputs/`, `lists/`, `dropdown/`, `bottom_sheet/`, `text/`, `selectors/`, …) and theme tokens in [`lib/core/themes/`](lib/core/themes/). Today the same widgets get re-implemented per feature (`_SaveButton`, `_ConfirmButton`, `_BottomButtons` …) — stop adding to that pile.

The go-forward home for the kit is the **`bull_ui` design-system package** (`packages/bull_ui`; see ARCHITECTURE.md "Design-system package"). Provenance: **`BB*` = legacy `lib/core/widgets`, `Bull*` = `bull_ui`**. A feature whose UI is built on the kit imports only `package:bull_ui/bull_ui.dart` for widgets — never `package:flutter/material.dart`/`cupertino.dart`/`widgets.dart` (the `coins` feature is the first to enforce this). Migration of `core/widgets` into `bull_ui` is incremental (one scoped PR at a time), so both still exist; prefer a `Bull*` widget when one exists, otherwise follow the workflow below against `lib/core/widgets/`.

Workflow when you need a widget:

1. **Search `lib/core/widgets/` first.** If something close exists, use it.
2. **If close but missing a variant**, extend the core widget (new prop, new constructor) rather than fork. One source of truth, no copy-paste.
3. **If genuinely new and reused by ≥ 2 features**, put it in `lib/core/widgets/<category>/` from the start — that *is* growing the UI Kit.
4. **If used by exactly one feature**, it lives in `<feature>/ui/widgets/` — but write it composable enough to be promoted later (no hardcoded colors, no hardcoded text, take callbacks not bloc refs).
5. **Widgets never live under `adapters/`, `frameworks/`, `domain/`, or `application/`.** UI goes in `ui/` or `lib/core/widgets/`. Full stop.
6. **No hardcoded user-facing strings.** Always `context.loc.<key>` — the `BuildContext` extension (`build_context_x.dart`) that wraps `AppLocalizations.of(context)`; it is the dominant convention (≈2564 uses vs 3 raw `AppLocalizations.of`). Add the key to [`localization/`](localization/) and run `make translations`. A duplicated literal across screens means a missing l10n key.
7. **Theme tokens only** — colors, spacing, typography pulled from the theme. See rule #10 above.

When you spot a duplicate of an existing core widget in feature code, flag it in the PR description as a follow-up cleanup. Don't silently leave it. Don't fix unrelated duplicates in the same PR either — that breaks atomic commits.

## Commits — atomic + Conventional

Format: `type(scope): description`

- **type**: `feat | fix | refactor | chore | docs | test | ci | build | perf | style`
- **scope**: feature folder name (`wallet`, `send`, `payjoin`, `swap`, `core`, `ci`, `hooks`, …) — lowercase, single noun.
- **description**: imperative, lowercase, no trailing period, ≤72 chars total subject line. Human-friendly and compact — describe the *why* if non-obvious; the *what* is in the diff.

Rules:

- **Atomic.** One logical change per commit. A feature + its refactor = two commits. A fix + cleanup = two commits. Independently revertable.
- **No `Co-Authored-By` trailer.**
- **No `--no-verify`.** Pre-commit must pass on its own.
- Reference the recent history (`dc3642801`, `14cce2ad6`, `1fecb0bb8`) for style.

## Tests

- Use cases and entities with business rules **must** have unit tests.
- **Layout:** tests live in `test/` mirroring `lib/` (`test/features/<feature>/…`, core under `test/core_test/`); files end `_test.dart`.
- **Tooling:** `bloc_test` for blocs/cubits, `mocktail`/`mockito` for collaborators; prefer **fakes** for repositories/datasources — the abstract interfaces exist precisely so you can swap a real implementation for a test double.
- `make unit-test` for the test you wrote. Don't claim done until it's green.
- Integration tests live in `integration_test/` and need device/.env fixtures.

## Dependencies (pubspec)

- **GitHub refs only, never `path:` deps.** All cross-repo packages are pinned via `git: { url, ref }` ([example](pubspec.yaml#L11-L14)). Path deps don't ship.
- Adding a dep? Bump `pubspec.yaml`, run `make deps`, commit `pubspec.lock` in the same commit.

## Verify before suggesting

**Your training data is stale; the ecosystem isn't.** Flutter, Dart, BDK, Boltz, payjoin, freezed, drift, go_router, bloc — all churn fast. Pasting an API or library version from memory is the fastest way to waste the user's time.

Before recommending a library, API surface, syntax, flag, version, or pattern:

1. **Anchor on the current date.** Run `date -u +%Y-%m-%d` so you know what "recent" actually means in this session — your knowledge cutoff isn't today.
2. **Cross-check at least one trustworthy source**, freshness-matched to that date:
   - **Official docs** for the library/framework (pub.dev for Dart packages, docs.flutter.dev, dart.dev).
   - **GitHub** of the project itself — `gh release list`, `gh issue list -S "is:open <topic>"`, the actual source. Releases ≤12 months old preferred.
   - **StackOverflow** answers from the last ~2 years — older answers often describe deprecated APIs.
   - **Reddit** (`r/FlutterDev`, `r/dartlang`, `r/programming`) for community sentiment on patterns and recent breakage reports.
3. **Cite the source** in chat or in the PR description: title + URL + a date stamp. "Per pub.dev/packages/foo (2026-04-15) …".
4. **If you can't verify, say so explicitly** — "I think X but couldn't confirm" beats stating a wrong API confidently.

This applies equally to architectural suggestions, tooling, CI tricks, command flags, and security recommendations. Confidence ≠ correctness.

## CLI and tooling habits

- **Prefer `rtk <cmd>`** if `command -v rtk` succeeds — token-optimized proxy. Falls back transparently if not installed.
- **Use `gh`** for GitHub (PRs, issues, runs, releases). If `gh` is unavailable, use `curl` or Fetch against the REST API or fetch the page — never invent URLs.
- **Learn unknown CLIs with `--help` first.** Don't guess flags. `<cmd> --help`, `<cmd> subcommand --help`, then act.
- **Get the current date with `date -u +%Y-%m-%d`** before judging anything as "recent" or "outdated" — see the verification section above.

## Security (self-custodial wallet — treat as load-bearing)

This app holds users' keys. A leak is not a bug, it's a loss of funds. Hold these as hard as the architecture rules:

- **Never log secrets.** Mnemonics, seeds, xprivs, PINs, raw key material never reach logs, Sentry, or analytics. Scrub before reporting; assume anything logged is exfiltrated.
- **Secrets are ephemeral.** Read from `flutter_secure_storage` at point of use; don't cache key material in long-lived bloc/singleton state. Treat a revealed value as short-lived.
- **Sealed UI for display.** Show a secret through a widget that reads it internally and never returns it (the `MnemonicView` pattern — see ARCHITECTURE.md "Sealed UI as a security tool"); never add a getter that hands the raw value to a caller.
- **Block capture on secret screens** — `no_screenshot` plus exclusion from the semantics/accessibility tree.
- **Validate at the domain boundary.** Addresses, amounts, descriptors are value objects that reject invalid input at construction (rule #9) — never trust a raw string deeper in.
- When a change touches key material, signing, or backup/recovery, **say so explicitly in the PR** so it gets the right review.

## Don'ts (the short list)

- Don't run `flutter` / `dart` without `fvm`.
- Don't run `flutter analyze <path>` — whole project only.
- Don't bypass `.git_hooks/pre-commit`.
- Don't import across feature internals — facade only.
- Don't put business logic in BLoCs or `/lib/core`.
- Don't log, cache, or expose secrets (mnemonic / seed / xpriv / PIN) — see Security.
- Don't return a `data/` model from a repository, or a non-published type from a facade — boundaries carry domain types only.
- Don't reinvent a widget that already exists in `lib/core/widgets/`.
- Don't hardcode user-facing strings — use `context.loc.<key>`.
- Don't hard-wrap prose mid-sentence in markdown, comments, PR descriptions, or commit bodies — write each sentence on one continuous line and let the editor soft-wrap. Manual line breaks belong only between paragraphs or list items.
- Don't add `path:` deps to pubspec.
- Don't amend or force-push without explicit ask.
- Don't add `Co-Authored-By`.
- Don't ship code you couldn't verify (`make unit-test` red = not done).
- Don't recommend an API, version, or pattern from memory — verify against pub.dev / GitHub / docs first.

## When in doubt

Plan first, code second. Read the existing facade of the feature you're touching. If the architecture file says one thing and the code says another, the file wins — flag the legacy code as a follow-up rather than copying it.
