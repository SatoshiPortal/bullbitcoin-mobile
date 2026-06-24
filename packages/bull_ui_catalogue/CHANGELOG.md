# Changelog

## Unreleased

- Seed the `bull_ui_catalogue` Widgetbook (v3) app: a use-case per `Bull*`
  component, plus a **`Foundation/`** section showcasing Colours, Radius,
  Spacing and the text scale.
- Light/dark theme addon (carries the `BullTheme` extension, mirroring how the
  app injects it) + a text-scale addon.
- Navigator-less `appBuilder` workaround for the widgetbook-v3 / Flutter-3.44.1
  `Navigator._history.isNotEmpty` assertion (the v4 migration is deferred — v4 is
  a full authoring-model rewrite).
- Run locally with `make catalogue` (dev-only; never shipped in the app, zero
  reproducible-build impact).
