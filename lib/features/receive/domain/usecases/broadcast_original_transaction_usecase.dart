import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
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
    switch (result) {
      case Ok(:final value):
        return Ok(value);
      case Err(failure: PayjoinFallbackUnavailableFailure(:final logMessage)):
        return Err(ReceiveBroadcastOriginalTxUnavailableFailure(logMessage));
      case Err(:final failure):
        log.warning(
          'Failed to broadcast the original transaction: '
          '${failure.logMessage}',
        );
        return Err(ReceiveBroadcastOriginalTxFailure(failure.logMessage));
    }
  }
}
