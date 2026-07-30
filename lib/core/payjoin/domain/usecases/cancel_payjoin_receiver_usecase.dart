import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';

/// Abandons a receiver session that cannot be used anymore.
///
/// The exchange buy flow creates its receiver before placing the order because
/// the BIP21 URI must travel in that request. This removes an orphaned receiver
/// when placement fails or an unconfirmed order is later abandoned.
///
/// The payment lands either way: an abandoned session that still receives a
/// request declines it and broadcasts the sender's own original transaction.
class CancelPayjoinReceiverUsecase {
  final PayjoinRepository _payjoinRepository;

  const CancelPayjoinReceiverUsecase({required this._payjoinRepository});

  Future<void> execute(String payjoinId) async {
    try {
      await _payjoinRepository.cancelReceiver(payjoinId);
    } catch (e) {
      throw CancelPayjoinReceiverException(e.toString());
    }
  }
}

class CancelPayjoinReceiverException extends BullException {
  CancelPayjoinReceiverException(super.message);
}
