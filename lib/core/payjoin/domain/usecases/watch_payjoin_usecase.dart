import 'package:bb_mobile/core/payjoin/data/services/payjoin_watcher_service_impl.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';

class WatchPayjoinUsecase {
  final PayjoinWatcherService _payjoinWatcher;

  const WatchPayjoinUsecase({
    required PayjoinWatcherService payjoinWatcherService,
  }) : _payjoinWatcher = payjoinWatcherService;

  Stream<PayjoinReceiver> execute({List<String>? ids}) {
    try {
      return _payjoinWatcher.payjoins
          .where((payjoin) => payjoin is PayjoinReceiver)
          .cast<PayjoinReceiver>()
          .where((payjoin) => ids == null || ids.contains(payjoin.id));
    } catch (e) {
      throw WatchPayjoinException(e.toString());
    }
  }
}

class WatchPayjoinException implements Exception {
  final String message;

  WatchPayjoinException(this.message);
}
