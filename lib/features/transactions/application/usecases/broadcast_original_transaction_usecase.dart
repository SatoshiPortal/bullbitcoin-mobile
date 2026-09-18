import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';

class BroadcastOriginalTransactionUsecase {
  final PayjoinSender _sender;

  const BroadcastOriginalTransactionUsecase(this._sender);

  Future<bool> canExecute(PayjoinSession payjoin) async {
    return switch (await _sender.canBroadcastOriginal(payjoin.id)) {
      Ok(:final value) => value,
      Err() => false,
    };
  }

  @useResult
  Future<Result<PayjoinSession, TransactionFailure>> execute(
    PayjoinSession payjoin,
  ) async {
    return switch (await _sender.broadcastOriginal(payjoin.id)) {
      Ok(:final value) => Ok(value),
      Err(failure: PayjoinFallbackUnavailableFailure()) => const Err(
        TransactionPayjoinFallbackUnavailableFailure(),
      ),
      Err(:final failure) => Err(
        TransactionPayjoinBroadcastFailure(
          'broadcastOriginal failed: ${failure.runtimeType}',
        ),
      ),
    };
  }
}
