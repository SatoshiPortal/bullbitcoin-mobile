# bull_ui

The Bull Bitcoin design-system component library — the go-forward source of truth for
shared UI primitives. It is the first melos workspace member (`packages/bull_ui`).

Every public widget is prefixed `Bull*` (e.g. `BullText`, `BullButton`, `BullScaffold`).
This prefix is provenance: **`BB*` = legacy widgets in `lib/core/widgets`, `Bull*` = here**.
The two coexist during the incremental migration; `BB*` originals are retired
feature-by-feature in later scoped PRs as usages migrate. Nothing is moved or renamed —
`bull_ui` components are duplicated copies, so existing app code is untouched.

## Theme injection

`bull_ui` is **brightness-agnostic** and never hardcodes a colour. The app injects the
palette: it builds a `BullTheme` (a `ThemeExtension`) from `AppColors.light` and another
from `AppColors.dark`, and registers each on the matching `ThemeData` via `extensions:`.
Components read colours through `context.bull` (e.g. `context.bull.red`); derived fills use
`tokenColor.withValues(alpha: …)` so they adapt to both light and dark automatically.

Brightness-invariant tokens (radii, spacing, type over Golos Text) are static consts:
`BullRadius`, `BullSpacing`, `BullTextStyles`. Icons are wrapped via `BullIcon(BullIcons.…)`.

Fonts (Golos Text, Bebas Neue) are declared at the app root and resolve by family name
across the workspace — `bull_ui` references them by name and does not re-ship the `.ttf`s.

## Import surface

Consumers import a single barrel:

```dart
import 'package:bull_ui/bull_ui.dart';
```

It re-exports a curated `show` list of `package:flutter/widgets.dart` layout/foundation
symbols plus every `Bull*` component and the theme. Internals live under `lib/src/`.

## Components

Duplicated from `lib/core/widgets/**` as dependency-clean `Bull*` copies (the
`BB*`/core originals are left untouched). Grouped by barrel category:

**Buttons** — `BullButton`, `BullToolButton`, `BullTabMenuVerticalButton`
(`TabMenuVerticalButton`), `BullViewerActionButton` (`ViewerActionButton`).

**Inputs** — `BullCheckbox`, `BullFilterChip`, `BullInputText` (`BBInputText`),
`BullPasteInput` (`PasteInput`), `BullDropdown` (`BBDropdown`),
`BullSelectableList` + `BullSelectableListItem` (`SelectableList`),
`BullDialPad` (`DialPad`), `BullAmountInputFormatter` (`AmountInputFormatter`),
`BullLowerCaseTextFormatter` (`LowerCaseTextFormatter`).

**Controls** — `BullSegmented`, `BullSwipeAction`, `BullSwitch` (`BBSwitch`).

**Feedback** — `BullRefreshIndicator` (`BBRefreshIndicator`), `BullShimmerBox`/
`BullShimmerLine`, `BullSnackBar`, `BullCountdown` (`Countdown`),
`BullFadingLinearProgress` (`FadingLinearProgress`).

**Layout** — `BullScrollableColumn` (`ScrollableColumn`), `BullStackedPage`
(`StackedPage`), `BullPullableBody` (`BBPullableBody`).

**Data display** — `BullAddressText`, `BullBadge`, `BullInfoBar`,
`BullLabelChip`, `BullStatTile`, `BullText` (`BBText`), `BullOptionsTag`
(`OptionsTag`), `BullInfoCard` (`InfoCard`), `BullPriceCard` (`PriceCard`),
`BullBackupOptionCard` (`BackupOptionCard`), `BullBorderedTile`
(`BorderedTappableTile`), `BullTransactionDirectionBadge`
(`TransactionDirectionBadge`), `BullSettingsEntryItem` (`SettingsEntryItem`),
`BullDetailsTable` + `BullDetailsTableItem` (`DetailsTable` / `DetailsTableItem`).

**Overlays** — `BullBottomSheet`, `BullDialog`, `BullPickerSheet`
(`BBPickerSheet`), `BullInstructionsSheet` (`InstructionsBottomSheet`).

**Chrome** — `BullScaffold`, `BullTopBar`, `BullSelectionActionBar`.

## Not yet migrated (needs dep abstraction)

These `core/widgets` widgets still reach into `package:bb_mobile/*` (or otherwise
can't preserve their public API on top of the clean kit) and are **deferred**
until the dependency is abstracted out of the widget:

| Widget | Blocker |
| --- | --- |
| `MultiTapTrigger` | `package:bb_mobile/core/widgets/snackbar_utils.dart` — its public `tapsReachedMessageTextColor` / `tapsReachedMessageBackgroundColor` API can't be honoured by `BullSnackBar.show` (String-only), so migrating would lose API. |
| `CopyInput`, `BBKeyboardActions` | depend on `package:bb_mobile/*` localization / app utils. |
| `BBButton` (`buttons/button.dart`) | already superseded by `BullButton`; not a 1:1 copy. |
| Cards: `ActionCard`, `AutoswapWarningCard`, `BackupCard`, `BalanceCard`, `ProviderCart`, `WalletCard` | `package:bb_mobile/*` (router, l10n, feature models, `Assets`). |
| `BBKeyboardActions` | needs `package:keyboard_actions/keyboard_actions.dart`, not declared in `bull_ui/pubspec.yaml` (no new deps rule). |
| Bottom sheets: `AdvancedOptions`, `ComingSoon`, `Warning`, `NotLoggedIn`, `DeleteAccount*`, `Logout*`, `TranslationWarning` | `context.loc` localization and/or `package:bb_mobile/*` router & assets. |
| Cards: `AutoswapWarningCard` | `context.loc` (`autoswapWarningCard*` strings) + `context.font` from `package:bb_mobile/core/utils/build_context_x.dart`. |
| Loading: `ProgressScreen`, `StatusScreen` | `ProgressScreen` imports `package:bb_mobile/generated/flutter_gen/assets.gen.dart`; `StatusScreen` uses `context.loc` + `BBButton`. |
| Viewers: `AddressViewer`, `TransactionViewer`, `InvoiceViewer`, `LogViewer`, `QrScanner`, `NfcScanner`, `ShareLogs`, `Bip85Derivation`, `MnemonicWidget`, `CoinSelectionBottomSheet`, `AppLanguagePicker`, `BackupSuccessScreen`, `PriceInput`, `TransactionsByDayList`, `BalanceRow`, `RecoverbullVaultProviderSelector` | `package:bb_mobile/*` (entities, l10n, assets, feature blocs). |
