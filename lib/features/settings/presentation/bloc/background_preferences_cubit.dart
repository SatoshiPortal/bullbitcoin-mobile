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
    bool requestPermission = false,
    bool openSettings = false,
  }) async {
    final generation = ++_generation;
    try {
      final next = await _preferences.execute(
        interval: interval,
        requestPermission: requestPermission,
        openSettings: openSettings,
      );
      if (!isClosed && generation == _generation) emit(next);
    } on Exception {
      if (!isClosed && generation == _generation) {
        emit(
          const BackgroundPreferencesState(failure: SettingsStorageFailure()),
        );
      }
    }
  }
}
