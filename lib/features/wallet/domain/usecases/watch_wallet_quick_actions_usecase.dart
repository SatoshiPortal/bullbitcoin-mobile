import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';

/// The wallet owns which actions are available for each exchange state.
class WalletQuickActionsPolicy {
  const WalletQuickActionsPolicy(this.access);

  final ExchangeAccess access;

  Set<QuickAction> available({required bool platformAllowsExchange}) => {
    QuickAction.transfer,
    QuickAction.map,
    QuickAction.settings,
    QuickAction.history,
    QuickAction.support,
    QuickAction.priceHistory,
    if (access.enabledForHome && platformAllowsExchange) ...{
      QuickAction.buy,
      QuickAction.sell,
      QuickAction.pay,
      QuickAction.exchange,
    },
  };

  List<QuickAction> get defaults => const [
    QuickAction.map,
    QuickAction.transfer,
    QuickAction.history,
    QuickAction.settings,
  ];
}

class WatchWalletQuickActionsUsecase {
  WatchWalletQuickActionsUsecase(this._access);

  final ExchangeAccessFacade _access;

  WalletQuickActionsPolicy get current =>
      WalletQuickActionsPolicy(_access.current);

  Stream<WalletQuickActionsPolicy> watch() =>
      _access.watch().map(WalletQuickActionsPolicy.new);
}
