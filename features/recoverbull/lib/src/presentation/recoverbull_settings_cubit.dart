import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/usecases/fetch_recoverbull_url_usecase.dart';
import '../domain/usecases/store_recoverbull_url_usecase.dart';
import '../public/recoverbull.dart';

final class RecoverBullSettingsState {
  final bool loading;
  final bool saving;
  final String url;
  final RecoverBullMonitoringStatus? monitoring;

  const RecoverBullSettingsState({
    this.loading = true,
    this.saving = false,
    this.url = '',
    this.monitoring,
  });

  RecoverBullSettingsState copyWith({
    bool? loading,
    bool? saving,
    String? url,
    RecoverBullMonitoringStatus? monitoring,
  }) => RecoverBullSettingsState(
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    url: url ?? this.url,
    monitoring: monitoring ?? this.monitoring,
  );
}

final class RecoverBullSettingsCubit extends Cubit<RecoverBullSettingsState> {
  final LogSink log;
  final FetchRecoverbullUrlUsecase fetchUrl;
  final StoreRecoverbullUrlUsecase storeUrl;
  final RecoverBullAttemptMonitoringController? monitoring;

  RecoverBullSettingsCubit({
    required this.log,
    required this.fetchUrl,
    required this.storeUrl,
    this.monitoring,
  }) : super(const RecoverBullSettingsState());

  Future<void> load() async {
    try {
      final url = await fetchUrl.execute();
      final monitoringStatus = await monitoring?.status();
      if (isClosed) return;
      emit(
        state.copyWith(
          loading: false,
          url: url.toString(),
          monitoring: monitoringStatus,
        ),
      );
    } catch (error, _) {
      log.warning(
        'recoverbull.settings.load_failed error_type=${error.runtimeType}',
      );
      if (!isClosed) emit(state.copyWith(loading: false));
    }
  }

  Future<bool> save(String value) async {
    emit(state.copyWith(saving: true));
    try {
      final url = Uri.parse(value);
      await storeUrl.execute(url);
      if (isClosed) return false;
      emit(state.copyWith(saving: false, url: url.toString()));
      return true;
    } catch (error, _) {
      log.warning(
        'recoverbull.settings.save_failed error_type=${error.runtimeType}',
      );
      if (!isClosed) emit(state.copyWith(saving: false));
      return false;
    }
  }

  Future<void> setMonitoringEnabled(bool enabled) async {
    final controller = monitoring;
    if (controller == null) return;
    await controller.setEnabled(enabled);
    final status = await controller.status();
    if (!isClosed) emit(state.copyWith(monitoring: status));
  }
}
