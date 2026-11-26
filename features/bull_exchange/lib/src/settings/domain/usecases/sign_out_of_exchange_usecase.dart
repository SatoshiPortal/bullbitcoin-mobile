import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../exchange_access_actions.dart';

/// Signs out of the exchange and clears the session; never activates.
class SignOutOfExchangeUsecase {
  final Future<Result<void, ExchangeFailure>> Function() _signOut;

  SignOutOfExchangeUsecase(ExchangeAccessActions actions)
    : _signOut = actions.signOut;

  /// The same sign-out straight on the exchange, for screens the host's
  /// access actions don't reach (the account actions of exchange settings).
  SignOutOfExchangeUsecase.of(Exchange exchange) : _signOut = exchange.signOut;

  @useResult
  Future<Result<void, ExchangeFailure>> execute() => _signOut();
}
