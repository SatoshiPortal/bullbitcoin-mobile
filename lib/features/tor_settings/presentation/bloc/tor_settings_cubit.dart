import 'dart:async';

import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/update_tor_settings_usecase.dart';
import 'package:bb_mobile/core/tor/tor_status.dart';
import 'package:bb_mobile/features/tor_settings/domain/usecases/check_tor_connection_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'tor_settings_cubit.freezed.dart';
part 'tor_settings_state.dart';

class TorSettingsCubit extends Cubit<TorSettingsState> {
  TorSettingsCubit({
    required GetSettingsUsecase getSettingsUsecase,
    required UpdateTorSettingsUsecase updateTorSettingsUsecase,
    required CheckTorConnectionUsecase checkTorConnectionUsecase,
  })  : _getSettingsUsecase = getSettingsUsecase,
        _updateTorSettingsUsecase = updateTorSettingsUsecase,
        _checkTorConnectionUsecase = checkTorConnectionUsecase,
        super(const TorSettingsState());

  final GetSettingsUsecase _getSettingsUsecase;
  final UpdateTorSettingsUsecase _updateTorSettingsUsecase;
  final CheckTorConnectionUsecase _checkTorConnectionUsecase;
  Timer? _statusCheckTimer;

  Future<void> init() async {
    await _loadSettings();
    await checkConnectionStatus();
    _startPeriodicStatusCheck();
  }

  Future<void> _loadSettings() async {
    final settings = await _getSettingsUsecase.execute();
    emit(
      state.copyWith(
        useTorProxy: settings.useTorProxy,
        torProxyPort: settings.torProxyPort,
      ),
    );
  }

  Future<void> updateTorSettings({
    required bool useTorProxy,
    required int torProxyPort,
  }) async {
    await _updateTorSettingsUsecase.execute(
      useTorProxy: useTorProxy,
      torProxyPort: torProxyPort,
    );
    await refreshSettings();
  }

  void _startPeriodicStatusCheck() {
    _statusCheckTimer?.cancel();
    if (state.useTorProxy) {
      _statusCheckTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => checkConnectionStatus(),
      );
    }
  }

  Future<void> checkConnectionStatus() async {
    if (!state.useTorProxy) {
      return;
    }

    emit(state.copyWith(status: TorStatus.connecting));

    final status = await _checkTorConnectionUsecase.execute(state.torProxyPort);
    emit(state.copyWith(status: status));
  }

  Future<void> refreshSettings() async {
    await _loadSettings();
    await checkConnectionStatus();
    // Restart periodic check (will start/stop based on useTorProxy state)
    _startPeriodicStatusCheck();
  }

  @override
  Future<void> close() {
    _statusCheckTimer?.cancel();
    return super.close();
  }
}
