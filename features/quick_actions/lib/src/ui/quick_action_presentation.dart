import 'package:bull_ui/bull_ui.dart';

import '../../generated/l10n/quick_actions_localizations.dart';
import '../domain/quick_action.dart';

extension QuickActionPresentation on QuickAction {
  String label(QuickActionsLocalizations l10n, {bool amountsHidden = false}) =>
      switch (this) {
        QuickAction.toggleAmounts => amountsHidden ? l10n.show : l10n.hide,
        QuickAction.pay => l10n.pay,
        QuickAction.transfer => l10n.transfer,
        QuickAction.map => l10n.map,
        QuickAction.history => l10n.history,
        QuickAction.settings => l10n.settings,
        QuickAction.support => l10n.support,
        QuickAction.priceHistory => l10n.priceHistory,
        QuickAction.exchange => l10n.quickActionTrade,
      };

  String fullLabel(
    QuickActionsLocalizations l10n, {
    bool amountsHidden = false,
  }) => switch (this) {
    QuickAction.toggleAmounts =>
      amountsHidden ? l10n.showAmounts : l10n.hideAmounts,
    QuickAction.priceHistory => l10n.priceHistoryFull,
    QuickAction.transfer => l10n.transfer,
    QuickAction.support => l10n.supportFull,
    _ => label(l10n, amountsHidden: amountsHidden),
  };

  IconData get icon => switch (this) {
    QuickAction.toggleAmounts => BullIcons.currencyBitcoin,
    QuickAction.pay => BullIcons.receiptLong,
    QuickAction.transfer => BullIcons.swapHoriz,
    QuickAction.map => BullIcons.map,
    QuickAction.history => BullIcons.history,
    QuickAction.settings => BullIcons.settings,
    QuickAction.support => BullIcons.supportAgent,
    QuickAction.priceHistory => BullIcons.showChart,
    QuickAction.exchange => BullIcons.candlestickChart,
  };
}
