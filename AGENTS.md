# AGENTS.md

Instructions for AI coding agents working in this repo. Cross-tool standard ([agents.md](https://agents.md/)) — read by Cursor, Codex, Copilot, Jules, Devin, Factory, Aider, Zed, recent Claude Code, and others. If you use a tool that only reads `CLAUDE.md`, create a one-line local `CLAUDE.md` containing `See @AGENTS.md` (Claude Code resolves `@` imports). Not committed — `CLAUDE.md` is gitignored so each contributor sets it up if needed.

## Project

Bull Bitcoin Mobile: self-custodial Bitcoin + Liquid + Lightning wallet. Flutter/Dart, BLoC, Drift/SQLite, GoRouter, get_it DI. See [README.md](README.md) for product details.

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

Read [ARCHITECTURE.md](ARCHITECTURE.md) and [FEATURES.md](FEATURES.md) before adding or moving code. **The repo is in active migration**: at audit time, only 3 of ~55 features have `application/`, none have `public/` or `watchers/`. The target structure described below is what new code must follow. Existing code may violate these rules — do not replicate violations, but don't refactor unrelated legacy in the same PR either.

Some rules below are canonical (textbook Clean/Hex Arch), others are deliberate project conventions. Both are binding here, but knowing which is which helps when an external source contradicts a rule — the project rules win inside this repo, but cite the canonical source if the conversation moves to *why*. Project rules are explicitly labeled.

Hard rules:

1. **Feature isolation — facade is our chosen pattern.** Modular Flutter has several valid options (facade, abstract use-case interfaces, event bus, mediator); this codebase picks facade. **Target location** (per ARCHITECTURE.md): `<feature>/public/<feature>_facade.dart`. **Current legacy** (e.g. [`labels_facade.dart`](lib/features/labels/labels_facade.dart)): facade at feature root. New facades use the target location; don't move legacy ones in unrelated PRs. Never import another feature's `domain/`, `application/`, `adapters/`, `interface_adapters/`, or `frameworks/`.
2. **Layer direction.** UI → Presentation (BLoC/Cubit) → Application (use cases + ports) → Domain. Adapters depend on ports; never the reverse. (Note: Uncle Bob calls the use-case ring "Interactors"; we use `application/` — both are valid, this is our naming.) The inward-only dependency rule itself is [hexagonal-canonical](https://alistair.cockburn.us/hexagonal-architecture).
3. **Watchers go through use cases**, not repositories. `watcher → use case → repository`.
4. **BLoCs are thin — in our architecture.** No orchestration, no business decisions, no complex transforms; those live in use cases. (Note: [bloclibrary.dev](https://bloclibrary.dev/architecture/) treats the bloc layer itself as the business-logic layer above repositories — our "BLoC is thin, use case below it" stance is a deliberate Clean-Arch refinement, not bloclibrary canon.) **Project convention**: never call another feature's facade directly from a BLoC — wrap it in your own feature's use case (in `application/usecases/`), and the BLoC calls that wrapper. This is the cure for "business logic in presentation" that ARCHITECTURE.md flags as the most common pitfall.
5. **Local widget state stays in `StatefulWidget`.** BLoC/Cubit is for business state only — what other layers care about. Form-field focus, animation controllers, expanded/collapsed panels, scroll positions: keep them in widget state. Mixing the two makes BLoC tests flaky and bloats state classes.
6. **Don't over-abstract adapters — project pragmatism.** A single repository is enough for trivial CRUD. Add a separate datasource layer only when there's meaningful transformation, multiple backends, or clear logic to separate. Two layers that forward-call each other are noise. (Note: textbook Clean Architecture for Android/Flutter typically *pairs* Repository + DataSource by default; we deliberately deviate on YAGNI grounds.)
7. **`/lib/core` is infrastructure only.** No feature/business logic. Generic primitives, drivers, helpers.
8. **Shared value objects go in `lib/core/primitives/`** (planned per [FEATURES.md](FEATURES.md) — folder doesn't exist yet at audit time, and `Secret`/`Address`/`Amount`/`Fingerprint` are not yet extracted as primitives). When you create a value object that more than one feature would reasonably use, put it in `lib/core/primitives/` from the start — that's how the primitives layer gets built. Before creating one, grep `lib/` for an existing class with the same intent.
9. **Prefer rich domain models** — methods that enforce invariants, not anemic DTOs mirroring DB rows. (Note: [Fowler's anemic-domain anti-pattern](https://www.martinfowler.com/bliki/AnemicDomainModel.html) is widely cited but [not universal](https://blog.inf.ed.ac.uk/sapm/2014/02/04/the-anaemic-domain-model-is-no-anti-pattern-its-a-solid-design/). This is our preference, aligned with ARCHITECTURE.md's "Anemic Domain Models" pitfall.)
10. **No raw colors.** Always pull from the theme. If the user describes a color in plain language, pick the closest theme color that works in both light and dark mode. Don't edit theme files unprompted.
11. **Errors per layer.** Naming per ARCHITECTURE.md:
    - `domain/` → `domain_errors.dart` (plural)
    - `application/` → `application_errors.dart` (plural)
    - `presentation/` → `presentation_errors.dart` (plural)

    The feature name is already implied by the path (`lib/features/<feature>/<layer>/`); don't repeat it in the filename. Caveat: the `fund_exchange` feature (the only feature today with all three error files) uses `fund_exchange_<layer>_error.dart` — feature-prefixed and singular. Legacy divergence; reconcile over time, don't replicate. Map foreign errors at every layer boundary; never leak another layer's error type.
12. **Acyclic feature graph.** Check [FEATURES.md](FEATURES.md) before adding a dependency.
13. **Keep the dependency graph live.** Any PR that adds a feature, removes a feature, or changes which other features it consumes via `public/` facades **must** update the mermaid graph in [FEATURES.md](FEATURES.md) in the same commit. The graph is documentation only if it matches the code — if you change one without the other, both become useless.
14. **Folders justify their existence — files don't justify folders.** A tiny piece of code is one file with a role suffix, not a folder of one file:
    - One use case → `<feature>/application/<verb>_<noun>_usecase.dart`. Don't create `application/usecases/` for a single file.
    - One entity → `<feature>/domain/<noun>.dart`. Don't create `domain/entities/` for a single file.
    - One datasource → `<feature>/frameworks/<noun>_datasource.dart`. Don't create `frameworks/datasources/` for a single file.

    Create the folder the moment a **second** file of that kind appears (or you know it's imminent in the same PR). Don't pre-create empty folders or use `.gitkeep`. Suffix carries the role; path carries the layer.

    **Exception (melos migration):** `packages/` and `features/` are intentionally pre-created with `.gitkeep` as reserved workspace homes for the in-progress monorepo migration — do not remove them or treat them as a rule-#14 violation. See the Monorepo / melos section.

When a request would break these rules, explain why and propose a compliant alternative. Don't silently comply.

## Naming conventions

Codified from a sweep of the actual codebase. ARCHITECTURE.md is silent on most of these; the rules below reflect what the dominant code already does. Where two conventions exist, the recommendation is the more common one — migrate toward it, don't replicate the minority.

**Folders** (inside a feature):

| Folder | Convention | Notes |
|---|---|---|
| `domain/entities/` | plural | 12 dirs vs 7 using `entity/` — prefer plural |
| `domain/usecases/` | plural, no underscore | 28 dirs vs 2 using `usecase/` — prefer plural |
| `application/usecases/` | plural, no underscore | New target location (3 features today) |
| `application/ports/` | plural | |
| `application/services/` | plural, optional | |
| `adapters/` | (folder name itself) | replaces older `interface_adapters/` |
| `frameworks/datasources/` | plural, no underscore | not `data_sources/` |
| `presentation/` | — | |
| `presentation/view_models/` | snake_case, optional | |
| `ui/screens/`, `ui/widgets/` | plural | |
| `public/` | — | facade lives directly inside |
| `watchers/` | plural, optional | |

**Files** — `snake_case`, singular suffix:

| Kind | Pattern | Example |
|---|---|---|
| Use case | `<verb>_<noun>_usecase.dart` | `broadcast_bitcoin_transaction_usecase.dart` |
| Repository port | `<noun>_repository.dart` | `bitcoin_wallet_repository.dart` |
| Repository impl | `<noun>_repository_impl.dart` **or** `<tech>_<noun>_repository.dart` | `exchange_rate_repository_impl.dart`, `drift_electrum_server_repository.dart` |
| Datasource port | `<noun>_datasource.dart` | `electrum_remote_datasource.dart` |
| Datasource impl | `<tech>_<noun>_datasource.dart` | `bdk_wallet_datasource.dart` |
| Entity / value object | `<noun>.dart` | `wallet.dart`, `auto_swap.dart` |
| Bloc | `<feature>_bloc.dart` | `send_bloc.dart` |
| Cubit | `<feature>_cubit.dart` | `settings_cubit.dart` |
| State | `<feature>_state.dart` | `send_state.dart` |
| Event | `<feature>_event.dart` | `send_event.dart` |
| Facade | `<feature>_facade.dart` | `labels_facade.dart` |
| Locator | `<feature>_locator.dart` | `wallet_locator.dart` |
| Errors | per rule #11 | |

**Classes** — `PascalCase`, matching local quirks:

- **Use cases**: `<Verb><Noun>Usecase` — **lowercase 'case'**, never `UseCase`. Codebase-wide convention (`GetSettingsUsecase`, `UpdateTorSettingsUsecase`, `BroadcastBitcoinTransactionUsecase`).
- **Datasources**: `<Name>Datasource` — **lowercase 's'**, never `DataSource`. Codebase-wide (`BdkWalletDatasource`, `BoltzDatasource`).
- **Repositories**: abstract port = `<Name>Repository`; concrete impl = `<Name>RepositoryImpl` or `<Tech><Name>Repository`. Pick the technology prefix when the backing tech is meaningful (Drift, Bdk, Boltz, GoogleDrive, Bullbitcoin); use `Impl` when the technology label would be awkward.
- **Entities & value objects**: bare noun, **no `Entity` suffix** (`Wallet`, `WalletUtxo`, `TransactionOutput`). Two legacy outliers (`BitboxDeviceEntity`, `LedgerDeviceEntity`) — don't replicate.
- **Ports** that aren't repositories: `<Name>Port` (`BlockchainPort`, `ElectrumConnectivityPort`).
- **Bloc/Cubit**: `<Feature>Bloc` / `<Feature>Cubit` (`SendBloc`, `SettingsCubit`).
- **State / Event**: `<Feature>State` / `<Feature>Event`, sealed with freezed when there are multiple cases.
- **Facade**: `<Feature>Facade` (`LabelsFacade`).
- **Watcher** (when introduced): `<Subject>Watcher`.
- **Error**: `<Feature><Layer>Error` for a single class, or a sealed `<Feature><Layer>Errors` family — match ARCHITECTURE.md rule #11.

When the same role exists with two names in the codebase, use the dominant one and flag the outlier as legacy. Don't rename outliers in unrelated PRs — that breaks atomic commits.

## UI Kit — reuse first, build the kit as you go

The codebase is migrating toward a real UI Kit. The skeleton already lives in [`lib/core/widgets/`](lib/core/widgets/) (`buttons/`, `cards/`, `inputs/`, `lists/`, `dropdown/`, `bottom_sheet/`, `text/`, `selectors/`, …) and theme tokens in [`lib/core/themes/`](lib/core/themes/). Today the same widgets get re-implemented per feature (`_SaveButton`, `_ConfirmButton`, `_BottomButtons` …) — stop adding to that pile.

Workflow when you need a widget:

1. **Search `lib/core/widgets/` first.** If something close exists, use it.
2. **If close but missing a variant**, extend the core widget (new prop, new constructor) rather than fork. One source of truth, no copy-paste.
3. **If genuinely new and reused by ≥ 2 features**, put it in `lib/core/widgets/<category>/` from the start — that *is* growing the UI Kit.
4. **If used by exactly one feature**, it lives in `<feature>/ui/widgets/` — but write it composable enough to be promoted later (no hardcoded colors, no hardcoded text, take callbacks not bloc refs).
5. **Widgets never live under `adapters/`, `frameworks/`, `domain/`, or `application/`.** UI goes in `ui/` or `lib/core/widgets/`. Full stop.
6. **No hardcoded user-facing strings.** Always `AppLocalizations.of(context).<key>`. Add the key to [`localization/`](localization/) and run `make translations`. A duplicated literal across screens means a missing l10n key.
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

## Don'ts (the short list)

- Don't run `flutter` / `dart` without `fvm`.
- Don't run `flutter analyze <path>` — whole project only.
- Don't bypass `.git_hooks/pre-commit`.
- Don't import across feature internals — facade only.
- Don't put business logic in BLoCs or `/lib/core`.
- Don't reinvent a widget that already exists in `lib/core/widgets/`.
- Don't hardcode user-facing strings — use `AppLocalizations`.
- Don't hard-wrap prose mid-sentence in markdown, comments, PR descriptions, or commit bodies — write each sentence on one continuous line and let the editor soft-wrap. Manual line breaks belong only between paragraphs or list items.
- Don't add `path:` deps to pubspec.
- Don't amend or force-push without explicit ask.
- Don't add `Co-Authored-By`.
- Don't ship code you couldn't verify (`make unit-test` red = not done).
- Don't recommend an API, version, or pattern from memory — verify against pub.dev / GitHub / docs first.

## When in doubt

Plan first, code second. Read the existing facade of the feature you're touching. If the architecture file says one thing and the code says another, the file wins — flag the legacy code as a follow-up rather than copying it.
