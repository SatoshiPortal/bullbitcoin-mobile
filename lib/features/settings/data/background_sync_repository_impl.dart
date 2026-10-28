import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/repositories/background_sync_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bull_logger/bull_logger.dart';

class BackgroundSyncRepositoryImpl implements BackgroundSyncRepository {
  final BackgroundSyncIntervalStore _store;
  final Future<void> Function() _reschedule;

  const BackgroundSyncRepositoryImpl({
    required this._store,
    required this._reschedule,
  });

  @override
  Future<Result<BackgroundSyncInterval, SettingsFailure>> interval() async {
    try {
      return Ok(await _store.read());
    } catch (e) {
      log.warning('Background sync interval unreadable: ${e.runtimeType}');
      return const Err(SettingsStorageFailure());
    }
  }

  @override
  Future<Result<void, SettingsFailure>> setInterval(
    BackgroundSyncInterval interval,
  ) async {
    try {
      await _store.write(interval);
    } catch (e) {
      log.warning('Background sync interval not saved: ${e.runtimeType}');
      return const Err(SettingsStorageFailure());
    }
    try {
      await _reschedule();
      return const Ok(null);
    } catch (e) {
      // Saved: the next app start applies it even if rescheduling failed now.
      log.warning('Background sync not rescheduled: ${e.runtimeType}');
      return const Err(SettingsUnexpectedFailure('reschedule failed'));
    }
  }
}
