import 'package:exchange/exchange.dart';

import '../exchange_access_actions.dart';

/// Every change of the exchange access.
class WatchExchangeAccessUsecase {
  final ExchangeAccessActions _actions;

  const WatchExchangeAccessUsecase(this._actions);

  Stream<ExchangeAccess> execute() => _actions.watch();
}
