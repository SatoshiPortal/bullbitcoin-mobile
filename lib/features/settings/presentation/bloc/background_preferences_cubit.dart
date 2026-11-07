import '../../domain/settings_failure.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/background_preferences_usecase.dart';
export '../../domain/usecases/background_preferences_usecase.dart'
    show BackgroundPreferencesState;

final class BackgroundPreferencesCubit
    extends Cubit<BackgroundPreferencesState> {
  final BackgroundPreferencesUsecase _preferences;
  Future<void> _pending = Future.value();
  BackgroundPreferencesCubit(this._preferences)
    : super(const BackgroundPreferencesState());

  Future<void> load({
    BackgroundSyncInterval? interval,
    bool requestPermission = false,
    bool openSettings = false,
  }) {
    // Keep every explicit action, including Off while persistence is pending.
    final next = _pending.then(
      (_) => _load(
        interval: interval,
        requestPermission: requestPermission,
        openSettings: openSettings,
      ),
    );
    _pending = next;
    return next;
  }

  Future<void> _load({
    BackgroundSyncInterval? interval,
    required bool requestPermission,
    required bool openSettings,
  }) async {
    try {
      final next = await _preferences.execute(
        interval: interval,
        requestPermission: requestPermission,
        openSettings: openSettings,
      );
      if (!isClosed) emit(next);
    } on Exception {
      if (!isClosed) {
        emit(
          const BackgroundPreferencesState(failure: SettingsStorageFailure()),
        );
      }
    }
  }
}
