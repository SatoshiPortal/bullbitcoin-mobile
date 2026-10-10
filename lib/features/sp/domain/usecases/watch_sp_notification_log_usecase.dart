import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notif_log.dart';

/// Exposes the SP notification log: the buffered history plus a live stream of
/// new lines. It outlives session recycles, so the settings console and the
/// app-lifetime watchers both read it.
class WatchSpNotificationLogUsecase {
  final SpAccountRepository _repository;

  WatchSpNotificationLogUsecase({required this._repository});

  ({List<SpNotifLogLine> log, Stream<SpNotifLogLine> updates}) execute() => (
    log: _repository.notificationLog,
    updates: _repository.notificationLogStream,
  );
}
