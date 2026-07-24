import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';

class WatchPayjoinUsecase {
  final PayjoinRepository _payjoinRepository;

  const WatchPayjoinUsecase({required this._payjoinRepository});

  /// Emits every payjoin update (both [PayjoinReceiver] and [PayjoinSender]),
  /// optionally scoped to [ids]. Consumers that only care about one side
  /// filter the concrete type themselves — the sender send-flow needs sender
  /// completion events, which a receiver-only filter here would swallow.
  Stream<Payjoin> execute({List<String>? ids}) {
    try {
      return _payjoinRepository.payjoinStream.where(
        (payjoin) => ids == null || ids.contains(payjoin.id),
      );
    } catch (e) {
      throw WatchPayjoinException(e.toString());
    }
  }
}

class WatchPayjoinException extends BullException {
  WatchPayjoinException(super.message);
}
