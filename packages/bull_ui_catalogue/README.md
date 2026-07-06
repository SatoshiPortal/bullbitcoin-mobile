# bull_ui_catalogue

Dev-only [Widgetbook](https://pub.dev/packages/widgetbook)-powered catalogue for
the `bull_ui` design system.

This package is **not** part of the production app. The app must never depend on
it, so it is never compiled into the APK and has zero reproducible-build impact
(it lives alongside the app like melos tooling). It exists purely to browse and
review every `Bull*` component in isolation, in light and dark themes at
different text scales.

## Why use-cases live here

`bull_ui` stays codegen-free and Widgetbook-free. All `@widgetbook.UseCase`
functions live in this package (`lib/use_cases/use_cases.dart`), so the design
system carries no Widgetbook annotations or generated files.

The `BullTheme` colours are normally injected by the app from its `AppColors`.
This package must not import the app, so `lib/catalogue_theme.dart` holds small
**catalogue-local** sample light/dark palettes mirroring the app — literals are
acceptable here in dev-only code, keeping `bull_ui` itself literal-free.

## Run locally

```bash
fvm flutter pub get                       # from repo root (workspace resolve)
cd packages/bull_ui_catalogue
fvm dart run build_runner build           # regenerate main.directories.g.dart
fvm flutter run -d chrome                 # browse the catalogue
```

`lib/main.directories.g.dart` is committed to the tree (the root `.gitignore`
ignores `*.g.dart`; this package's `.gitignore` negates that for the directories
file) so the catalogue runs without a build_runner pass.

## Publishing (deferred — local-only for now)

There is **no CI/Pages publishing in this PR** — browse the catalogue locally
with `make catalogue` (or the commands above).

Intended hosting for a follow-up: this repo's GitHub Pages serves `main:/docs`
(custom domain `wallet.bullbitcoin.com`), and a repo has only one Pages site, so
the catalogue would be published as a **subfolder** — built for web with
`--base-href /catalogue/` and dropped into `main:/docs/catalogue/` (preserving
the rest of `/docs`), served at `https://wallet.bullbitcoin.com/catalogue/`. That
requires CI to commit to `main`, so it's left for a dedicated change once the
catalogue renders cleanly (currently on widgetbook v3, pending a v4 migration).
