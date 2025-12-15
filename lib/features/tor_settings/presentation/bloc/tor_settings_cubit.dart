import 'dart:async';

import 'package:bb_mobile/core_deprecated/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/update_tor_settings_usecase.dart';
import 'package:bb_mobile/core_deprecated/tor/tor_status.dart';
import 'package:bb_mobile/features/tor_settings/domain/usecases/check_tor_proxy_connection_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'tor_settings_cubit.freezed.dart';
part 'tor_settings_state.dart';

class TorSettingsCubit extends Cubit<TorSettingsState> {
  TorSettingsCubit({
    required GetSettingsUsecase getSettingsUsecase,
    required UpdateTorSettingsUsecase updateTorSettingsUsecase,
    required CheckTorProxyConnectionUsecase checkTorConnectionUsecase,
  }) : _getSettingsUsecase = getSettingsUsecase,
       _updateTorSettingsUsecase = updateTorSettingsUsecase,
       _checkTorConnectionUsecase = checkTorConnectionUsecase,
       super(const TorSettingsState());

  final GetSettingsUsecase _getSettingsUsecase;
  final UpdateTorSettingsUsecase _updateTorSettingsUsecase;
  final CheckTorProxyConnectionUsecase _checkTorConnectionUsecase;

  Future<void> init() async {
    await _loadSettings();
    await checkConnectionStatus();
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

  Future<void> checkConnectionStatus() async {
    if (!state.useTorProxy) return;

    emit(state.copyWith(status: TorStatus.connecting));

    final status = await _checkTorConnectionUsecase.execute(state.torProxyPort);
    emit(state.copyWith(status: status));
  }

  Future<void> refreshSettings() async {
    await _loadSettings();
    await checkConnectionStatus();
  }
}
