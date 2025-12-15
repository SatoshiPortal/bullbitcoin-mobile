import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:bb_mobile/core_deprecated/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core_deprecated/payjoin/domain/repositories/payjoin_repository.dart';

class WatchPayjoinUsecase {
  final PayjoinRepository _payjoinRepository;

  const WatchPayjoinUsecase({required PayjoinRepository payjoinRepository})
    : _payjoinRepository = payjoinRepository;

  Stream<PayjoinReceiver> execute({List<String>? ids}) {
    try {
      return _payjoinRepository.payjoinStream
          .where((payjoin) => payjoin is PayjoinReceiver)
          .cast<PayjoinReceiver>()
          .where((payjoin) => ids == null || ids.contains(payjoin.id));
    } catch (e) {
      throw WatchPayjoinException(e.toString());
    }
  }
}

class WatchPayjoinException extends BullException {
  WatchPayjoinException(super.message);
}
