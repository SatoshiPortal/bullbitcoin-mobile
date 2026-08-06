import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

class BroadcastOriginalTransactionUsecase {
  final PayjoinSender _sender;

  const BroadcastOriginalTransactionUsecase(this._sender);

  Future<PayjoinSession> execute(String sessionId) async {
    final result = await _sender.broadcastOriginal(sessionId);
    return switch (result) {
      Ok(:final value) => value,
      Err() => throw BroadcastOriginalTransactionException(
        'Failed to broadcast original transaction',
      ),
    };
  }
}

class BroadcastOriginalTransactionException extends BullException {
  BroadcastOriginalTransactionException(super.message);
}
