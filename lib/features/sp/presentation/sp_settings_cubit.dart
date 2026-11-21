import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_backend_defaults_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_backend_config_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/update_sp_backend_config_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_notification_log_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notif_log.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_form.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_form_mixin.dart';
import 'package:bb_mobile/features/sp/presentation/sp_settings_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Settings backend-config form. The shared network/defaults/URL/test logic
/// lives in [SpBackendFormMixin]; this cubit adds the saved-config load, the
/// server-settings save, and the debug notification console.
class SpSettingsCubit extends Cubit<SpSettingsState>
    with SpBackendFormMixin<SpSettingsState> {
  final UpdateSpBackendConfigUsecase _updateSpBackendConfigUsecase;
  final WatchSpNotificationLogUsecase _watchNotificationLogUsecase;
  final TestSpBackendUsecase _testSpBackendUsecase;
  final LoadSpBackendConfigUsecase _loadSpBackendConfigUsecase;
  final GetSpBackendDefaultsUsecase _getSpBackendDefaultsUsecase;

  StreamSubscription<SpNotifLogLine>? _logSub;

  SpSettingsCubit({
    required this._updateSpBackendConfigUsecase,
    required this._watchNotificationLogUsecase,
    required this._testSpBackendUsecase,
    required this._loadSpBackendConfigUsecase,
    required this._getSpBackendDefaultsUsecase,
  }) : super(
         const SpSettingsState(form: SpBackendForm(isFetchingDefaults: true)),
       ) {
    final notifLog = _watchNotificationLogUsecase.execute();
    if (notifLog.log.isNotEmpty) {
      emit(state.copyWith(console: List.unmodifiable(notifLog.log)));
    }
    _logSub = notifLog.updates.listen((line) {
      final next = [...state.console, line];
      if (next.length > spNotifLogCap) next.removeAt(0);
      emit(state.copyWith(console: List.unmodifiable(next)));
    });
  }

  @override
  TestSpBackendUsecase get backendTestUsecase => _testSpBackendUsecase;

  @override
  GetSpBackendDefaultsUsecase get getBackendDefaultsUsecase =>
      _getSpBackendDefaultsUsecase;

  /// Load the SAVED backend config (custom URLs) when present, falling back to
  /// the network defaults. Then auto-test both so the current connection state
  /// shows without the user tapping.
  Future<void> initFromNetwork(BitcoinNetwork? network) async {
    if (state.initialized) return;
    final storedResult = await _loadSpBackendConfigUsecase.execute();
    if (isClosed) return;
    final SpBackendConfig? stored;
    switch (storedResult) {
      case Ok(:final value):
        stored = value;
      case Err(:final failure):
        emit(state.copyWith(form: state.form.copyWith(error: failure)));
        return;
    }
    if (stored != null) {
      emit(
        state.copyWith(
          initialized: true,
          minScanAmountSat: stored.minScanAmountSat,
          form: state.form.copyWith(
            network: stored.network,
            blindbitUrl: stored.blindbitUrl,
            electrumUrl: stored.electrumUrl,
            fetchConcurrencyFactor: stored.fetchConcurrencyFactor,
            matchConcurrencyFactor: stored.matchConcurrencyFactor,
            isFetchingDefaults: false,
          ),
        ),
      );
    } else if (network != null) {
      await setNetwork(network);
      if (isClosed) return;
    } else {
      return;
    }
    unawaited(testBlindbit());
    unawaited(testElectrum());
  }

  void clearConsole() => emit(state.copyWith(console: const []));

  void setFetchConcurrencyFactor(int factor) =>
      emit(state.withForm(state.form.applyFetchConcurrencyFactor(factor)));

  void setMatchConcurrencyFactor(int factor) =>
      emit(state.withForm(state.form.applyMatchConcurrencyFactor(factor)));

  Future<void> saveBackendConfig() async {
    if (!state.canSave) return;
    final form = state.form;
    await _saveConfig(
      () => _updateSpBackendConfigUsecase.execute(
        network: form.network,
        blindbitUrl: form.blindbitUrl,
        electrumUrl: form.electrumUrl,
        fetchConcurrencyFactor: form.fetchConcurrencyFactor,
        matchConcurrencyFactor: form.matchConcurrencyFactor,
      ),
    );
  }

  Future<SpFailure?> saveMinScanAmount(int amountSat) async {
    if (!state.initialized ||
        state.isSaving ||
        amountSat == state.minScanAmountSat) {
      return null;
    }
    final network = state.network;
    return _saveConfig(
      () => _updateSpBackendConfigUsecase.setMinScanAmount(
        network: network,
        minScanAmountSat: amountSat,
      ),
      minScanAmountSat: amountSat,
    );
  }

  Future<SpFailure?> _saveConfig(
    Future<Result<bool, SpFailure>> Function() save, {
    int? minScanAmountSat,
  }) async {
    emit(
      state.copyWith(
        isSaving: true,
        saved: false,
        form: state.form.copyWith(error: null),
      ),
    );
    final result = await save();
    if (isClosed) return null;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            isSaving: false,
            saved: value,
            minScanAmountSat: minScanAmountSat ?? state.minScanAmountSat,
          ),
        );
        return null;
      case Err(:final failure):
        emit(
          state.copyWith(
            isSaving: false,
            form: minScanAmountSat == null
                ? state.form.copyWith(error: failure)
                : state.form,
          ),
        );
        return failure;
    }
  }

  @override
  Future<void> close() async {
    await _logSub?.cancel();
    return super.close();
  }
}
