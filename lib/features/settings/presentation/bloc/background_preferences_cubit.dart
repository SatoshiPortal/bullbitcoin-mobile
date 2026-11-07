import 'dart:async';

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
  }) async {
    // Serialize completion, while each caller still receives its own error.
    final previous = _pending;
    final finished = Completer<void>();
    _pending = finished.future;
    try {
      await previous;
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
    } finally {
      finished.complete();
    }
  }
}
