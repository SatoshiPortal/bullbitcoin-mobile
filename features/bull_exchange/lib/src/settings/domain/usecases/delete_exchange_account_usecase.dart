import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Sends the account deletion request to support, then signs out only if the
/// account still belongs to the session that sent it. Acts on the exchange's
/// current session.
class DeleteExchangeAccountUsecase {
  final Exchange _exchange;

  const DeleteExchangeAccountUsecase(this._exchange);

  Future<Result<ExchangeAccountDeletionOutcome, ExchangeFailure>> execute() =>
      _exchange.deleteAccount();
}
