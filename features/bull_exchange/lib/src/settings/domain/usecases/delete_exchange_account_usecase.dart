import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Sends the account deletion request of a session to support, then signs
/// out only if the account still belongs to that session.
class DeleteExchangeAccountUsecase {
  final Exchange _exchange;

  const DeleteExchangeAccountUsecase(this._exchange);

  /// Without a session there is no account to delete.
  Future<Result<ExchangeAccountDeletionOutcome, ExchangeFailure>> execute(
    ExchangeSession? session,
  ) async => switch (session) {
    null => const Err(ExchangeNotAuthenticatedFailure()),
    final ExchangeSession session => await _exchange.deleteAccount(session),
  };
}
