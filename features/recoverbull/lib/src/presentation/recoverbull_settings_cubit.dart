import 'package:primitives/primitives.dart';
import '../domain/recoverbull_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/usecases/fetch_recoverbull_url_usecase.dart';
import '../domain/usecases/store_recoverbull_url_usecase.dart';
import '../domain/entities/recoverbull_monitoring_status.dart';
import '../domain/usecases/load_recoverbull_monitoring_status_usecase.dart';
import '../domain/usecases/change_recoverbull_monitoring_enabled_usecase.dart';

final class RecoverBullSettingsState {
  final bool loading;
  final bool saving;
  final String url;
  final RecoverBullMonitoringStatus? monitoring;
  final RecoverBullFailure? failure;

  const RecoverBullSettingsState({
    this.loading = true,
    this.saving = false,
    this.url = '',
    this.monitoring,
    this.failure,
  });

  RecoverBullSettingsState copyWith({
    bool? loading,
    bool? saving,
    String? url,
    RecoverBullMonitoringStatus? monitoring,
    RecoverBullFailure? failure,
  }) => RecoverBullSettingsState(
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    url: url ?? this.url,
    monitoring: monitoring ?? this.monitoring,
    failure: failure,
  );
}

final class RecoverBullSettingsCubit extends Cubit<RecoverBullSettingsState> {
  final LogSink log;
  final FetchRecoverbullUrlUsecase fetchUrl;
  final StoreRecoverbullUrlUsecase storeUrl;
  final LoadRecoverBullMonitoringStatusUsecase? monitoringStatus;
  final ChangeRecoverBullMonitoringEnabledUsecase? changeMonitoring;

  RecoverBullSettingsCubit({
    required this.log,
    required this.fetchUrl,
    required this.storeUrl,
    this.monitoringStatus,
    this.changeMonitoring,
  }) : super(const RecoverBullSettingsState());

  Future<void> load() async {
    final result = await fetchUrl.execute();
    if (isClosed) return;
    switch (result) {
      case Err(:final failure):
        emit(state.copyWith(loading: false, failure: failure));
      case Ok(:final value):
        final monitoringResult = await monitoringStatus?.execute();
        if (isClosed) return;
        emit(
          state.copyWith(
            loading: false,
            url: value.toString(),
            monitoring: monitoringResult?.fold((value) => value, (_) => null),
            failure: monitoringResult?.fold((_) => null, (failure) => failure),
          ),
        );
    }
  }

  Future<bool> save(String value) async {
    final url = Uri.tryParse(value);
    if (url == null) {
      emit(
        state.copyWith(
          failure: const RecoverBullUnexpectedFailure('Invalid key server URL'),
        ),
      );
      return false;
    }
    emit(state.copyWith(saving: true));
    final result = await storeUrl.execute(url);
    if (isClosed) return false;
    switch (result) {
      case Err(:final failure):
        emit(state.copyWith(saving: false, failure: failure));
        return false;
      case Ok():
        emit(state.copyWith(saving: false, url: url.toString()));
        return true;
    }
  }

  Future<void> setMonitoringEnabled(bool enabled) async {
    final usecase = changeMonitoring;
    if (usecase == null) return;
    final result = await usecase.execute(enabled);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(monitoring: value));
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }
}
