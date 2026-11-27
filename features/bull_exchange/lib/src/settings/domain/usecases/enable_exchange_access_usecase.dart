import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../exchange_access_actions.dart';

/// Turns the exchange access on.
class EnableExchangeAccessUsecase {
  final ExchangeAccessActions _actions;

  const EnableExchangeAccessUsecase(this._actions);

  @useResult
  Future<Result<void, ExchangeFailure>> execute() => _actions.enable();
}
