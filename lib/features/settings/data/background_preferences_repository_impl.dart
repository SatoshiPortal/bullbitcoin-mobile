import 'package:bull_logger/bull_logger.dart';
import '../domain/settings_failure.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import '../domain/repositories/background_preferences_repository.dart';

final class BackgroundPreferencesRepositoryImpl
    implements BackgroundPreferencesRepository {
  final BackgroundSyncIntervalStore _intervals;
  final NotificationPermissionsFacade _permissions;
  final Future<void> Function() _schedule;

  const BackgroundPreferencesRepositoryImpl(
    this._intervals,
    this._permissions,
    this._schedule,
  );

  @override
  Future<Result<BackgroundSyncInterval, SettingsFailure>> interval() async {
    try {
      return Ok(await _intervals.read());
    } on Exception {
      log.warning('Background interval read failed');
      return const Err(SettingsStorageFailure());
    }
  }

  @override
  Future<Result<bool, SettingsFailure>> notificationsAllowed() async =>
      (await _permissions.isEnabled()).mapErr(
        (_) => const SettingsStorageFailure(),
      );
  @override
  Future<Result<bool, SettingsFailure>> requestNotifications() async =>
      (await _permissions.request()).mapErr(
        (_) => const SettingsStorageFailure(),
      );
  @override
  Future<Result<void, SettingsFailure>> openNotificationSettings() async =>
      (await _permissions.openSystemSettings()).mapErr(
        (_) => const SettingsStorageFailure(),
      );
  @override
  Future<Result<void, SettingsFailure>> setInterval(
    BackgroundSyncInterval value,
  ) async {
    final result = await _intervals.write(value);
    if (result is Err) {
      log.warning('Background interval persistence failed');
      return const Err(SettingsStorageFailure());
    }
    try {
      await _schedule();
      log.config('Background interval saved=${value.name}');
      return const Ok(null);
    } on Exception {
      log.warning('Background schedule update failed');
      return const Err(SettingsStorageFailure());
    }
  }
}
