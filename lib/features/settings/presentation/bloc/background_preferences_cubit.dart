import '../../domain/settings_failure.dart';

import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/background_preferences_usecase.dart';
export '../../domain/usecases/background_preferences_usecase.dart'
    show BackgroundPreferencesState;

final class BackgroundPreferencesCubit
    extends Cubit<BackgroundPreferencesState> {
  final BackgroundPreferencesUsecase _preferences;
  int _generation = 0;
  BackgroundPreferencesCubit(this._preferences)
    : super(const BackgroundPreferencesState());

  Future<void> load({
    BackgroundSyncInterval? interval,
    bool? enabled,
    bool requestPermission = false,
    bool openSettings = false,
  }) async {
    // Notification actions must not invalidate a pending interval selection.
    if (interval != null || enabled != null) _generation++;
    final generation = _generation;
    try {
      final next = await _preferences.execute(
        interval: interval,
        enabled: enabled,
        requestPermission: requestPermission,
        openSettings: openSettings,
      );
      if (!isClosed && generation == _generation) {
        // A refusal stays shown until the system allows notifications: a
        // later refresh cannot tell a refused request from one never made.
        emit(
          BackgroundPreferencesState(
            // A failure elsewhere must not show background tasks as off.
            interval: next.interval ?? state.interval,
            allowed: next.allowed,
            refused: !next.allowed && (next.refused || state.refused),
            failure: next.failure,
          ),
        );
      }
    } on Exception {
      if (!isClosed && generation == _generation) {
        emit(
          BackgroundPreferencesState(
            interval: state.interval,
            failure: const SettingsStorageFailure(),
          ),
        );
      }
    }
  }
}
