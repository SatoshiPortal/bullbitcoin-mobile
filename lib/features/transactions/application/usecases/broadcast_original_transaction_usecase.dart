import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

class BroadcastOriginalTransactionUsecase {
  final PayjoinSender _sender;

  const BroadcastOriginalTransactionUsecase(this._sender);

  Future<bool> canExecute(PayjoinSession payjoin) async {
    return switch (await _sender.canBroadcastOriginal(payjoin.id)) {
      Ok(:final value) => value,
      Err() => false,
    };
  }

  Future<PayjoinSession> execute(PayjoinSession payjoin) async {
    final result = await _sender.broadcastOriginal(payjoin.id);
    return switch (result) {
      Ok(:final value) => value,
      Err(failure: PayjoinFallbackUnavailableFailure()) =>
        throw BroadcastOriginalTransactionUnavailableException(),
      Err() => throw BroadcastOriginalTransactionException(
        'Failed to broadcast original transaction',
      ),
    };
  }
}

class BroadcastOriginalTransactionException extends BullException {
  BroadcastOriginalTransactionException(super.message);
}

class BroadcastOriginalTransactionUnavailableException extends BullException {
  BroadcastOriginalTransactionUnavailableException()
    : super('Original transaction is no longer available for broadcast');
}
