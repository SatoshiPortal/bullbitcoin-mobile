import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';

/// Abandons a receiver session the user no longer wants.
///
/// The exchange buy flow is the caller that needs this: its BIP21 URI is handed
/// to the exchange when the order is created, before the confirmation screen
/// where the payjoin toggle lives, and no endpoint can revise it afterwards.
/// Turning the toggle off therefore cannot un-send the URI — it abandons our
/// side of the protocol instead, which makes the exchange fall back to paying
/// the address inside that URI with a plain transaction.
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
