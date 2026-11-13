import 'package:bull_ui/bull_ui.dart';

import '../../generated/l10n/quick_actions_localizations.dart';
import '../domain/quick_action.dart';

extension QuickActionPresentation on QuickAction {
  String label(QuickActionsLocalizations l10n) => switch (this) {
    QuickAction.buy => l10n.buy,
    QuickAction.sell => l10n.sell,
    QuickAction.pay => l10n.pay,
    QuickAction.transfer => l10n.transfer,
    QuickAction.map => l10n.map,
    QuickAction.settings => l10n.settings,
    QuickAction.history => l10n.history,
    QuickAction.support => l10n.support,
    QuickAction.priceHistory => l10n.priceHistory,
    QuickAction.exchange => l10n.quickActionTrade,
  };

  String fullLabel(QuickActionsLocalizations l10n) => switch (this) {
    QuickAction.priceHistory => l10n.priceHistoryFull,
    QuickAction.transfer => l10n.transferFull,
    QuickAction.support => l10n.supportFull,
    _ => label(l10n),
  };

  IconData get icon => switch (this) {
    QuickAction.buy => BullIcons.addCircleOutline,
    QuickAction.sell => BullIcons.sell,
    QuickAction.pay => BullIcons.receiptLong,
    QuickAction.transfer => BullIcons.swapHoriz,
    QuickAction.map => BullIcons.map,
    QuickAction.settings => BullIcons.settings,
    QuickAction.history => BullIcons.history,
    QuickAction.support => BullIcons.supportAgent,
    QuickAction.priceHistory => BullIcons.showChart,
    QuickAction.exchange => BullIcons.candlestickChart,
  };
}
