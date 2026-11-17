# Changelog

## Unreleased

- Restyle `BullSwitch` so its state reads at a glance: off is a hollow track ringed in `outline` around a grey thumb with a cross, on a `primary` track around a white thumb with a check. `BullSwitch.themeData` is the app's `switchTheme` too, so every Material `Switch` matches.
- Redesign `BullMnemonicKeyboard` as a full panel taking 35% of the screen or window height, suggestions and bottom inset included: a suggestion strip (best word in the middle, in bold), national letter rows given by the owner with backspace closing the third row, and a bottom row of language, accent page, scramble and enter keys sharing one function-key look. A disabled letter keeps its fill and shows a muted glyph. Accented letters come from a second page or a long press on their base letter; the language key opens a list of wordlists above it. Other scripts keep a scrolling grid with backspace in a column of their own. `BullKeyCap` takes an optional fill; the PIN pad keeps its look.
- Remove `BullDialPad`: the PIN screens, its only users, now use `BullPinPad`.
- Add `BullPinPad`, a digit keypad for PIN entry with the mnemonic keyboard's keys and sizing. Its bottom-left key toggles a scrambled layout, off by default and never persisted, reshuffled after every tap with `BullKeyScramble` (`Random.secure()`, at most two digits left in place). Keys never splash nor fade.
- Size the keys of `BullMnemonicKeyboard` from the space it is given (`BullKeypadGrid`): they grow with the width up to a desktop cap, follow a height budget in a short landscape window, and never shrink below a usable tap target.
- Move the recovery-phrase keyboard from the mnemonic import feature into the kit as `BullMnemonicKeyboard`, unchanged: the letters stay off the platform IME and the semantics tree, and while shuffled a key neither splashes nor fades.
- Add `BullSecretTextInput`, a labelled field for a secret typed on the system keyboard (a BIP39 passphrase): requests no IME suggestions, personalised learning or smart punctuation and disables Flutter platform autofill. The value is obscured behind a show/hide toggle, with no selection or copy, and excluded from the Flutter semantics tree. The system keyboard still receives typed text; native iOS autofill and VoiceOver behaviour require device verification.
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
