import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_backend_defaults_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_backend_config_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/recreate_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_notification_log_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notif_log.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_form.dart';
import 'package:bb_mobile/features/sp/presentation/sp_settings_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Settings backend-config form. The shared network/defaults/URL/test logic
/// lives in [SpBackendFormCubit]; this cubit adds the saved-config load, the
/// save-and-recreate action, and the debug notification console.
class SpSettingsCubit extends Cubit<SpSettingsState>
    with SpBackendFormCubit<SpSettingsState> {
  final RecreateSpWalletUsecase _recreateSpWalletUsecase;
  final WatchSpNotificationLogUsecase _watchNotificationLogUsecase;
  final TestSpBackendUsecase _testSpBackendUsecase;
  final LoadSpBackendConfigUsecase _loadSpBackendConfigUsecase;
  final GetSpBackendDefaultsUsecase _getSpBackendDefaultsUsecase;

  StreamSubscription<SpNotifLogLine>? _logSub;

  SpSettingsCubit({
    required this._recreateSpWalletUsecase,
    required this._watchNotificationLogUsecase,
    required this._testSpBackendUsecase,
    required this._loadSpBackendConfigUsecase,
    required this._getSpBackendDefaultsUsecase,
  }) : super(const SpSettingsState(isFetchingDefaults: true)) {
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
  Future<void> initFromNetwork(SpNetwork? network) async {
    if (state.initialized) return;
    final storedResult = await _loadSpBackendConfigUsecase.execute();
    if (isClosed) return;
    final SpBackendConfig? stored;
    switch (storedResult) {
      case Ok(:final value):
        stored = value;
      case Err(:final failure):
        emit(state.copyWith(error: failure));
        return;
    }
    if (stored != null) {
      final base = SpSettingsState(
        initialized: true,
        network: stored.network,
        blindbitUrl: stored.blindbitUrl,
        electrumUrl: stored.electrumUrl,
      );
      emit(
        base.copyWith(
          console: state.console,
          formRevision: state.formRevision + 1,
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

  Future<void> saveBackendConfig() async {
    if (!state.canSave) return;
    emit(state.copyWith(isSaving: true, saved: false, error: null));
    final result = await _recreateSpWalletUsecase.execute(
      network: state.network,
      blindbitUrl: state.blindbitUrl,
      electrumUrl: state.electrumUrl,
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(isSaving: false, saved: true));
      case Err(:final failure):
        emit(state.copyWith(isSaving: false, error: failure));
    }
  }

  @override
  Future<void> close() async {
    await _logSub?.cancel();
    return super.close();
  }
}
