import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';

class BroadcastOriginalTransactionUsecase {
  final PayjoinRepository _payjoin;

  BroadcastOriginalTransactionUsecase({
    required PayjoinRepository payjoinRepository,
  }) : _payjoin = payjoinRepository;

  Future<PayjoinReceiver> execute(PayjoinReceiver payjoin) async {
    try {
      if (payjoin.originalTxBytes == null) {
        throw BroadcastOriginalTransactionException(
          'No original transaction bytes to broadcast found for payjoin:'
          ' ${payjoin.id}',
        );
      }

      // Try to broadcast the original transaction for the payjoin
      final result = await _payjoin.tryBroadcastOriginalTransaction(payjoin);

      if (result == null) {
        throw BroadcastOriginalTransactionException(
          'Failed to broadcast original transaction for payjoin: ${payjoin.id}',
        );
      }

      return result;
    } catch (e) {
      throw BroadcastOriginalTransactionException('$e');
    }
  }
}

class BroadcastOriginalTransactionException implements Exception {
  final String message;

  BroadcastOriginalTransactionException(this.message);
}
