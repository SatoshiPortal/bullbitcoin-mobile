import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';

typedef SettingsQuickActionOptions = ({
  Set<QuickAction> available,
  List<QuickAction> defaults,
});

class WatchSettingsQuickActionsUsecase {
  const WatchSettingsQuickActionsUsecase(this._access);
  final ExchangeAccessFacade _access;

  SettingsQuickActionOptions _options(ExchangeAccess access) => (
    available: {
      QuickAction.map,
      QuickAction.transfer,
      QuickAction.history,
      QuickAction.settings,
      if (access.enabledForHome) ...{
        QuickAction.support,
        QuickAction.priceHistory,
        QuickAction.buy,
        QuickAction.sell,
        QuickAction.pay,
        QuickAction.exchange,
      },
    },
    defaults: const [
      QuickAction.map,
      QuickAction.transfer,
      QuickAction.history,
      QuickAction.settings,
    ],
  );
  SettingsQuickActionOptions get current => _options(_access.current);
  Stream<SettingsQuickActionOptions> execute() => _access.watch().map(_options);
}
