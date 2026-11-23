# bull_ui

The Bull Bitcoin design system publishes reusable Flutter components through `package:bull_ui/bull_ui.dart`. Shared component names use the `Bull*` prefix. App features supply localized copy, assets and callbacks and compose the components into their own screens.

## Theme injection

`package:bull_ui/app_theme.dart` builds the app's light and dark `ThemeData` from `AppColors`. It registers the matching `BullTheme` and the other design tokens through `bullUiExtensions`. The components remain brightness-agnostic: they read the extensions on the active theme. `BullKeypadColors` supplies separate light and dark presets so each glyph-on-key and key-on-panel pair has the same contrast in both themes.
Components read colours through `context.bull` (e.g. `context.bull.primary`). `BullTheme` is a
**1:1 mirror of `AppColors`** — same field names — so `AppTheme` wires every field through
without translation. Derived fills use `tokenColor.withValues(alpha: …)` so they adapt to both
light and dark automatically.

## Foundation tokens

Brightness-invariant tokens are static consts, from the design system:

- **`BullShapes`** — corner radius per role (`context.bullShapes.card`); Bull's values live in `BullShapes.standard`, and an app passes others with `bullUiExtensions(shapes: …)`.
- **`BullSpacing`** — `zero·xxs·xs·sm·md·lg·xl·xxl·xxxl` = `0·4·8·12·16·24·32·48·64`.
- **`BullTypography`** — text style per role (`display·headline·title·subtitle·body·label·caption`), read with `context.bullType.body` or `BullText(role: .body)`; Bull's values live in `BullTypography.standard`, nothing below 12; an app passes another family with `bullUiExtensions(typography: BullTypography.standard.withFamily(…))`, keeping the scale. A caller may change a role's weight or colour, never its size. Older components still read the Material `TextTheme`.
- **`BullKeypadColors`** — keypad panel, key and glyph colours per role (`context.bullKeypad.key`), in `BullKeypadColors.light` and `.dark`.
- **`BullLoaderTheme`** — which animation `BullLoader` plays (`BullLoaderStyle.cubes` or `.spinner`); Bull's is `BullLoaderTheme.standard` (cubes), and an app picks another with `bullUiExtensions(loader: …)`.
- **Icons** via `BullIcon(BullIcons.…)`.

**Tokens are fixed — never scaled by screen size.** Responsiveness is a *layout* concern
(breakpoints, `LayoutBuilder`, max-width wrappers, adaptive columns), not a token concern; text
already honours the user's `MediaQuery.textScaler`. The catalogue (`packages/bull_ui_catalogue`)
has a `Foundation/` section showcasing colours, radius, spacing and the text scale.

Fonts (Golos Text, Bebas Neue) are declared at the app root and resolve by family name
across the workspace — `bull_ui` references them by name and does not re-ship the `.ttf`s.

## Action buttons

Use `BullButton.primary` for the single action that confirms or advances a screen (including deletion), and `BullButton.secondary` for alternatives, cancel actions and symmetric choices. Both resolve fill and foreground from the injected theme (`primary`/`onPrimary` and `secondary`/`onSecondary`); ordinary buttons never use fixed tokens or error colors. A screen may have no primary action.

Pass `onPressed: null` to disable a role button. `size: BullButtonSize.small` and `compact: true` affect layout, and retain a minimum 48 dp target when the parent permits it. Use `BullInlineIconButton` with a translated tooltip for icon-only actions. In a pair, use icons on both buttons or neither.

`BullAdvancedOptionsLink` is reserved for advanced options: an underlined primary-colored label with a minimum 48 dp target. Labels and tooltips come translated from the consumer.

The legacy `BullButton.big`/`.small` constructors and their appearance parameters remain during the Ark migration. Their `bgColor`/`textColor` properties represent explicit legacy colors; role buttons resolve their colors at build time and leave these properties null. The `onPressed` getter remains non-null for existing consumers; use `disabled` to inspect availability.

## Import surface

Consumers import a single barrel:

```dart
import 'package:bull_ui/bull_ui.dart';
```

It re-exports a curated `show` list of `package:flutter/widgets.dart` layout/foundation
symbols plus every `Bull*` component and the theme. Internals live under `lib/src/`.

## Components

The public barrel groups components by role.

**Buttons** — `BullButton`, `BullToolButton`, `BullTabMenuVerticalButton`,
`BullViewerActionButton`.

**Inputs** — `BullCheckbox`, `BullFilterChip`, `BullInputText`,
`BullLabeledTextInput`, `BullSecretTextInput`, `BullPasteInput`, `BullDropdown`,
`BullSelectableList` + `BullSelectableListItem`, `BullMnemonicKeyboard`, `BullPinPad`,
`BullAmountInputFormatter`, `BullLowerCaseTextFormatter`, `BullKeyboardActions`.

**Controls** — `BullSegmented`, `BullSwipeAction`, `BullSwitch`.

**Feedback** — `BullRefreshIndicator`, `BullShimmerBox`/`BullShimmerLine`,
`BullSnackBar`, `BullCountdown`, `BullFadingLinearProgress`, `BullLoader`
(`.large()` on a progress screen, `.small()` inline; its GIF ships in this package's `assets/`),
`BullErrorState`.

**Layout** — `BullScrollableColumn`, `BullStackedPage`, `BullPullableBody`.

**Data display** — `BullAddressText`, `BullBadge`, `BullInfoBar`,
`BullLabelChip`, `BullStatTile`, `BullText`, `BullOptionsTag`,
`BullInfoCard`, `BullAlertCard`, `BullPriceCard`,
`BullBackupOptionCard`, `BullBorderedTile`, `BullTransactionDirectionBadge`,
`BullSettingsEntryItem`, `BullDetailsTable` + `BullDetailsTableItem`, `BullQrCode`, `BullInvoiceViewer`, `BullTransactionViewer`, `BullConfirmationHeader`, and `BullConfirmationRow`.

**Overlays** — `BullBottomSheet`, `BullDialog`, `BullConfirmDialog`,
`BullPickerSheet`, `BullInstructionsSheet`, `BullDisclosureLink`, and `BullDisclosureSheet`.

**Chrome** — `BullScaffold`, `BullTopBar`, `BullSelectionActionBar`.

**Support** — `BullSupportButton` (`.big`, `.icon`, `.text`, `.tile`) and `BullSupportScope`, which the app places above its screens to supply the contact-support action. Without a scope the button renders disabled.
