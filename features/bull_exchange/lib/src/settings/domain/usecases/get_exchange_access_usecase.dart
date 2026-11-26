import 'package:exchange/exchange.dart';

import '../exchange_access_actions.dart';

/// The exchange access as it is now.
class GetExchangeAccessUsecase {
  final ExchangeAccessActions _actions;

  const GetExchangeAccessUsecase(this._actions);

  ExchangeAccess execute() => _actions.current();
}
