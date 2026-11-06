import '../settings_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:background_tasks/background_tasks.dart';
import '../repositories/background_preferences_repository.dart';

/// All permission requests originate in an explicit settings action.
final class BackgroundPreferencesUsecase {
  final BackgroundPreferencesRepository _repository;
  const BackgroundPreferencesUsecase(this._repository);

  Future<BackgroundPreferencesState> execute({
    BackgroundSyncInterval? interval,
    bool requestPermission = false,
    bool openSettings = false,
  }) async {
    if (interval != null) {
      final result = await _repository.setInterval(interval);
      if (result case Err(:final failure)) {
        return BackgroundPreferencesState(failure: failure);
      }
    }
    if (requestPermission) {
      final result = await _repository.requestNotifications();
      if (result case Err(:final failure)) {
        return BackgroundPreferencesState(failure: failure);
      }
    }
    if (openSettings) {
      final result = await _repository.openNotificationSettings();
      if (result case Err(:final failure)) {
        return BackgroundPreferencesState(failure: failure);
      }
    }
    final selected = await _repository.interval();
    final allowed = await _repository.notificationsAllowed();
    return allowed.fold(
      (value) => BackgroundPreferencesState(interval: selected, allowed: value),
      (_) => BackgroundPreferencesState(
        interval: selected,
        failure: const SettingsStorageFailure(),
      ),
    );
  }
}

final class BackgroundPreferencesState {
  final BackgroundSyncInterval? interval;
  final bool allowed;
  final SettingsFailure? failure;
  const BackgroundPreferencesState({
    this.interval,
    this.allowed = false,
    this.failure,
  });
}
