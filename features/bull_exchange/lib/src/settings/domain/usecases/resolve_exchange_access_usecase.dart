import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../exchange_access_actions.dart';

/// Settles an access that could not be read or a sign-out that did not
/// finish.
class ResolveExchangeAccessUsecase {
  final ExchangeAccessActions _actions;

  const ResolveExchangeAccessUsecase(this._actions);

  @useResult
  Future<Result<void, ExchangeFailure>> execute() => _actions.resolve();
}
