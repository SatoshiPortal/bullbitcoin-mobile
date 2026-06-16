# Changelog

## Unreleased

- Expand `BullTheme` with `secondary`, `onSecondary`, `secondaryFixedDim`,
  `border`, `onSurface`, `onSurfaceVariant` and `scrim` (plus `copyWith`/`lerp`
  and the app-side `_bullThemeFrom` builder), sourced from `AppColors`.
- Duplicate the dependency-clean set of `lib/core/widgets/**` as `Bull*`
  copies: `BullInputText`, `BullPasteInput`, `BullDropdown`,
  `BullSelectableList`, `BullDialPad`, `BullAmountInputFormatter`,
  `BullLowerCaseTextFormatter`, `BullCountdown`, `BullFadingLinearProgress`,
  `BullScrollableColumn`, `BullStackedPage`, `BullPullableBody`,
  `BullOptionsTag`, `BullInfoCard`, `BullPriceCard`, `BullBackupOptionCard`,
  `BullBorderedTile`, `BullTransactionDirectionBadge`, `BullSettingsEntryItem`,
  `BullTabMenuVerticalButton`, `BullViewerActionButton`. See the README
  "Components" / "Not yet migrated" tables.
- Duplicate the remaining dependency-clean widgets: `BullDetailsTable` +
  `BullDetailsTableItem` (`DetailsTable` / `DetailsTableItem`),
  `BullPickerSheet` (`BBPickerSheet`) and `BullInstructionsSheet`
  (`InstructionsBottomSheet`). No new `BullTheme` fields were required — they
  reuse the existing `surface`, `border`, `onSurface`, `red` and `text` colours.
- Widget tests for `BullDropdown`, `BullCountdown` and `BullDialPad`.

## 0.0.1

- Seed the `bull_ui` design-system package: `BullTheme` (`ThemeExtension`),
  `BullRadius`/`BullSpacing`/`BullTextStyles`/`BullIcon` tokens, and the first
  set of `Bull*` components for the Coins view (issue #760).
