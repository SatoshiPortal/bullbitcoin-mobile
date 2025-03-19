import 'package:bb_mobile/_core/domain/entities/payjoin.dart';
import 'package:bb_mobile/_core/domain/services/payjoin_watcher_service.dart';

class GetPayjoinUpdatesUsecase {
  final PayjoinWatcherService _payjoinWatcher;

  const GetPayjoinUpdatesUsecase({
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
      throw PayjoinUpdatesException(e.toString());
    }
  }
}

class PayjoinUpdatesException implements Exception {
  final String message;

  PayjoinUpdatesException(this.message);
}
