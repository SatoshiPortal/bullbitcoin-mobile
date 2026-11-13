import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';

typedef SettingsQuickActionOptions = ({
  Set<QuickAction> available,
  List<QuickAction> defaults,
});

class WatchSettingsQuickActionsUsecase {
  const WatchSettingsQuickActionsUsecase(this._access);
  final ExchangeFacade _access;

  SettingsQuickActionOptions _options(ExchangeAccess access) => (
    available: {
      QuickAction.map,
      QuickAction.transfer,
      QuickAction.history,
      QuickAction.settings,
      QuickAction.support,
      QuickAction.priceHistory,
      if (ExchangeAvailability.resolve(platformAllowed: true, access: access) !=
          ExchangeAvailability.hidden) ...{
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
  SettingsQuickActionOptions get current => _options(_access.currentAccess);
  Stream<SettingsQuickActionOptions> execute() =>
      _access.watchAccess().map(_options);
}
