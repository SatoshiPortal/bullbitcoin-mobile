import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Reads the account of the session. A session that is no longer current is
/// refused; a credential the server rejects expires (see
/// [Exchange.loadAccount]).
class GetAccountUsecase {
  final Exchange _exchange;

  const GetAccountUsecase(this._exchange);

  Future<Result<UserSummary, ExchangeFailure>> execute(
    ExchangeSession session,
  ) => _exchange.loadAccount(session);
}
