import 'package:meta/meta.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:primitives/primitives.dart';

import '../settings_failure.dart';

abstract interface class BackgroundPreferencesRepository {
  Future<BackgroundSyncInterval> interval();
  @useResult
  Future<Result<bool, SettingsFailure>> notificationsAllowed();
  @useResult
  Future<Result<void, SettingsFailure>> setInterval(
    BackgroundSyncInterval value,
  );
  @useResult
  Future<Result<bool, SettingsFailure>> requestNotifications();
  @useResult
  Future<Result<void, SettingsFailure>> openNotificationSettings();
}
