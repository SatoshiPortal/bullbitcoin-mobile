import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../exchange_access_actions.dart';

/// Signs out of the exchange and clears the session; never activates.
class SignOutOfExchangeUsecase {
  final ExchangeAccessActions _actions;

  const SignOutOfExchangeUsecase(this._actions);

  @useResult
  Future<Result<void, ExchangeFailure>> execute() => _actions.signOut();
}
