import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_background_sync_interval_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_background_sync_interval_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// State: the interval in effect, null until read; [failure] when the last
/// change did not apply.
class BackgroundSyncState {
  final BackgroundSyncInterval? interval;
  final SettingsFailure? failure;

  const BackgroundSyncState({this.interval, this.failure});
}

class BackgroundSyncCubit extends Cubit<BackgroundSyncState> {
  final GetBackgroundSyncIntervalUsecase _get;
  final SetBackgroundSyncIntervalUsecase _set;

  BackgroundSyncCubit({
    required GetBackgroundSyncIntervalUsecase getBackgroundSyncIntervalUsecase,
    required SetBackgroundSyncIntervalUsecase setBackgroundSyncIntervalUsecase,
  }) : _get = getBackgroundSyncIntervalUsecase,
       _set = setBackgroundSyncIntervalUsecase,
       super(const BackgroundSyncState());

  Future<void> load() async {
    final result = await _get.execute();
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => BackgroundSyncState(interval: value),
      Err(:final failure) => BackgroundSyncState(failure: failure),
    });
  }

  Future<void> choose(BackgroundSyncInterval interval) async {
    final previous = state.interval;
    if (interval == previous) return;
    emit(BackgroundSyncState(interval: interval));
    final result = await _set.execute(interval);
    if (isClosed) return;
    switch (result) {
      case Ok():
        log.config('Background sync interval chosen=${interval.name}');
      case Err(failure: final SettingsStorageFailure failure):
        emit(BackgroundSyncState(interval: previous, failure: failure));
      case Err(:final failure):
        // Saved, so it applies at the next start even though the schedule
        // could not be changed right now.
        emit(BackgroundSyncState(interval: interval, failure: failure));
    }
  }
}
