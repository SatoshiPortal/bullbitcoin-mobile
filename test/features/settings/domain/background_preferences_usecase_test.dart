import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/repositories/background_preferences_repository.dart';
import 'package:bb_mobile/features/settings/domain/usecases/background_preferences_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

class Preferences implements BackgroundPreferencesRepository {
  int requests = 0;
  var selected = BackgroundSyncInterval.hour1;
  var failWrite = false;
  var failRead = false;
  @override
  Future<Result<BackgroundSyncInterval, SettingsFailure>> interval() async =>
      failRead ? const Err(SettingsStorageFailure()) : Ok(selected);
  @override
  Future<Result<bool, SettingsFailure>> notificationsAllowed() async =>
      const Ok(false);
  @override
  Future<Result<bool, SettingsFailure>> requestNotifications() async {
    requests++;
    return const Ok(false);
  }

  @override
  Future<Result<void, SettingsFailure>> openNotificationSettings() async =>
      const Ok(null);
  @override
  Future<Result<void, SettingsFailure>> setInterval(
    BackgroundSyncInterval value,
  ) async {
    if (failWrite) return const Err(SettingsStorageFailure());
    selected = value;
    return const Ok(null);
  }
}

void main() {
  test('read failures remain typed without requesting permission', () async {
    final repository = Preferences()..failRead = true;
    final state = await BackgroundPreferencesUsecase(repository).execute();
    expect(state.failure, isA<SettingsStorageFailure>());
    expect(repository.requests, 0);
  });

  test(
    'loading and interval changes never prompt; only explicit request does',
    () async {
      final repository = Preferences();
      final usecase = BackgroundPreferencesUsecase(repository);
      expect((await usecase.execute()).allowed, isFalse);
      await usecase.execute(interval: BackgroundSyncInterval.minutes30);
      expect(repository.requests, 0);
      expect(repository.selected, BackgroundSyncInterval.minutes30);
      expect((await usecase.execute(requestPermission: true)).allowed, isFalse);
      expect(repository.requests, 1);
    },
  );
  test(
    'failed preference write stays visible and preserves prior interval',
    () async {
      final repository = Preferences()..failWrite = true;
      final result = await BackgroundPreferencesUsecase(
        repository,
      ).execute(interval: BackgroundSyncInterval.off);
      expect(result.failure, isA<SettingsStorageFailure>());
      expect(repository.selected, BackgroundSyncInterval.hour1);
    },
  );
}
