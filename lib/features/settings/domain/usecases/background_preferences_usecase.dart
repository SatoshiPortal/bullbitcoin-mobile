import '../settings_failure.dart';

import 'package:primitives/primitives.dart';
import 'package:background_tasks/background_tasks.dart';

import '../repositories/background_preferences_repository.dart';

/// All permission requests originate in an explicit settings action.
final class BackgroundPreferencesUsecase {
  final BackgroundPreferencesRepository _repository;
  const BackgroundPreferencesUsecase(this._repository);

  /// [enabled] turns background tasks on or off, see
  /// [BackgroundSyncInterval.withEnabled].
  Future<BackgroundPreferencesState> execute({
    BackgroundSyncInterval? interval,
    bool? enabled,
    bool requestPermission = false,
    bool openSettings = false,
  }) async {
    if (enabled != null && interval == null) {
      switch (await _repository.interval()) {
        case Ok(:final value):
          final next = value.withEnabled(enabled);
          if (next != value) interval = next;
        case Err(:final failure):
          return BackgroundPreferencesState(failure: failure);
      }
    }
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
    final selection = await _repository.interval();
    if (selection case Err(:final failure)) {
      return BackgroundPreferencesState(failure: failure);
    }
    final selected =
        (selection as Ok<BackgroundSyncInterval, SettingsFailure>).value;
    final allowed = await _repository.notificationsAllowed();
    return allowed.fold(
      (value) => BackgroundPreferencesState(
        interval: selected,
        allowed: value,
        // Granted but still not shown, e.g. the payment channel alone is
        // blocked: only the system settings can change it.
        refused: requestPermission && !value,
      ),
      (_) => BackgroundPreferencesState(
        interval: selected,
        failure: const SettingsStorageFailure(),
      ),
    );
  }
}

final class BackgroundPreferencesState {
  /// `null` until the stored choice has been read.
  final BackgroundSyncInterval? interval;

  /// Read from the system, never remembered by the app.
  final bool allowed;

  /// Notifications are still not shown after the request just made: the
  /// system may not ask again, only its settings can change it.
  final bool refused;
  final SettingsFailure? failure;

  const BackgroundPreferencesState({
    this.interval,
    this.allowed = false,
    this.refused = false,
    this.failure,
  });

  bool? get enabled => interval?.isEnabled;
}
