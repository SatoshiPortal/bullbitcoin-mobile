import '../domain/settings_failure.dart';

import 'package:background_tasks/background_tasks.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

import '../domain/repositories/background_preferences_repository.dart';

final class BackgroundPreferencesRepositoryImpl
    implements BackgroundPreferencesRepository {
  final BackgroundSchedule _schedule;
  final NotificationPermissionsFacade _permissions;

  BackgroundPreferencesRepositoryImpl(this._schedule, this._permissions);

  @override
  Future<Result<BackgroundSyncInterval, SettingsFailure>> interval() async =>
      (await _schedule.interval()).mapErr(
        (_) => const SettingsStorageFailure(),
      );

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
  ) async =>
      (await _schedule.setInterval(value))
          .mapErr((_) => const SettingsStorageFailure());
}
