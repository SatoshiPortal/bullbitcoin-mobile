# Changelog

## Unreleased

- **Foundation tokens now follow the design system / official theme.** `BullTheme`
  is the full 1:1 `AppColors` mirror (all ~40 fields, official names); `BullRadius`
  adopts the design scale (`0/4/8/12/16/28/32/999`) and `BullSpacing` the design
  scale (`0/4/8/12/16/24/32/48/64`); `BullTextStyles` is **removed** — type comes
  from the Material `TextTheme` (`AppFonts`). All `Bull*` components were remapped
  (`context.bull.red→primary`, `btc→onTertiary`, `muted→textMuted`,
  `card→cardBackground`, radius/spacing → new scales). Tokens are fixed (not
  screen-scaled); responsiveness is a layout concern.
- `BullSwipeAction` action panel wrapped in `FittedBox(scaleDown)` so the
  icon+label never overflows a short row.

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
