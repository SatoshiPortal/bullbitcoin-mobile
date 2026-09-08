import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';

class BroadcastOriginalTransactionUsecase {
  final PayjoinSender _sender;

  const BroadcastOriginalTransactionUsecase(this._sender);

  @useResult
  Future<Result<PayjoinSession, ReceiveFailure>> execute(
    String sessionId,
  ) async {
    final result = await _sender.broadcastOriginal(sessionId);
    return switch (result) {
      Ok(:final value) => Ok(value),
      Err(failure: PayjoinFallbackUnavailableFailure(:final logMessage)) => Err(
        ReceiveBroadcastOriginalTxUnavailableFailure(logMessage),
      ),
      Err(:final failure) => Err(
        ReceiveBroadcastOriginalTxFailure(failure.logMessage),
      ),
    };
  }
}
