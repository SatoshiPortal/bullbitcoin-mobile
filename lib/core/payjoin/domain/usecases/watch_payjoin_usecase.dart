import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/services/payjoin_watcher_service.dart';

class WatchPayjoinUsecase {
  final PayjoinWatcherService _payjoinWatcher;

  const WatchPayjoinUsecase({
    required PayjoinWatcherService payjoinWatcherService,
  }) : _payjoinWatcher = payjoinWatcherService;

  Stream<Payjoin> execute({List<String>? ids}) {
    try {
      return _payjoinWatcher.payjoins.where(
        (payjoin) {
          if (ids == null) {
            return true;
          }
          return ids.contains(payjoin.id);
        },
      );
    } catch (e) {
      throw WatchPayjoinException(e.toString());
    }
  }
}

class WatchPayjoinException implements Exception {
  final String message;

  WatchPayjoinException(this.message);
}
