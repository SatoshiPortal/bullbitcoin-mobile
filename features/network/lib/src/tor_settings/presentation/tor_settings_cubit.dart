import 'dart:async';

import 'package:bull_tor/tor.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/check_external_tor_connection_usecase.dart';
import '../domain/load_tor_preferences_usecase.dart';
import '../domain/update_tor_proxy_usecase.dart';
import '../domain/update_tor_transport_mode_usecase.dart';
import '../domain/watch_tor_settings_usecase.dart';

part 'tor_settings_cubit.freezed.dart';
part 'tor_settings_state.dart';

class TorSettingsCubit extends Cubit<TorSettingsState> {
  TorSettingsCubit({
    required this._loadPreferences,
    required this._updateTorProxyUsecase,
    required this._updateTorTransportModeUsecase,
    required this._watchSettingsUsecase,
    required this._checkExternalTorConnectionUsecase,
  }) : super(const TorSettingsState());

  final LoadTorPreferencesUsecase _loadPreferences;
  final UpdateTorProxyUsecase _updateTorProxyUsecase;
  final UpdateTorTransportModeUsecase _updateTorTransportModeUsecase;
  final WatchTorSettingsUsecase _watchSettingsUsecase;
  final CheckExternalTorConnectionUsecase _checkExternalTorConnectionUsecase;
  StreamSubscription<TorConnectionState>? _connectionSubscription;

  /// Discards the answer of a check that a newer one has already superseded.
  int _checkGeneration = 0;
  int _settingsGeneration = 0;

  Future<void> init() async {
    final generation = ++_settingsGeneration;
    if (!await _loadSettings(generation: generation)) return;
    if (isClosed) return;
    // `??=`: two screens mount this cubit and each calls `init`. A second
    // subscription would leak the first and double every emission.
    _connectionSubscription ??= _watchSettingsUsecase.execute().listen((
      connection,
    ) {
      if (isClosed) return;
      emit(
        state.copyWith(
          embeddedConnection: connection,
          lastSuccessfulTransport: switch (connection) {
            TorReady(:final route) => route.transport,
            _ => state.lastSuccessfulTransport,
          },
        ),
      );
    });
    if (state.useTorProxy) {
      await checkConnectionStatus();
    }
  }

  Future<bool> _loadSettings({int? generation}) async {
    final result = await _loadPreferences.execute();
    if (isClosed || (generation != null && generation != _settingsGeneration)) {
      return false;
    }
    final settings = result.fold((value) => value, (_) => null);
    if (settings == null) return false;
    emit(
      state.copyWith(
        useTorProxy: settings.useTorProxy,
        torProxyPort: settings.torProxyPort,
        transportMode: settings.torTransportMode,
        lastSuccessfulTransport: settings.lastSuccessfulTorTransport,
        externalProxyAttempt: null,
        externalProxyAttemptPort: null,
      ),
    );
    return true;
  }

  Future<void> updateTransportMode(TorTransportMode mode) async {
    emit(state.copyWith(transportMode: mode));
    await _updateTorTransportModeUsecase.execute(mode);
  }

  Future<void> updateTorSettings({
    required bool useTorProxy,
    required int torProxyPort,
  }) async {
    final generation = ++_settingsGeneration;
    ++_checkGeneration;
    emit(
      state.copyWith(
        externalProxyAttempt: useTorProxy
            ? const TorConnecting(source: TorSource.external)
            : null,
        externalProxyAttemptPort: useTorProxy ? torProxyPort : null,
      ),
    );
    final connection = await _updateTorProxyUsecase.execute(
      useTorProxy: useTorProxy,
      torProxyPort: torProxyPort,
      isCurrent: () => !isClosed && generation == _settingsGeneration,
    );
    if (isClosed || generation != _settingsGeneration) return;
    final accepted = connection is TorReady || connection is TorStopped;
    emit(
      state.copyWith(
        useTorProxy: accepted ? useTorProxy : state.useTorProxy,
        torProxyPort: accepted ? torProxyPort : state.torProxyPort,
        connection: state.useTorProxy && !accepted
            ? state.connection
            : connection,
        externalProxyAttempt: accepted ? null : connection,
        externalProxyAttemptPort: accepted ? null : torProxyPort,
      ),
    );
  }

  Future<void> checkConnectionStatus() async {
    if (isClosed || !state.useTorProxy) return;

    final generation = ++_checkGeneration;
    emit(
      state.copyWith(
        connection: const TorConnecting(source: TorSource.external),
      ),
    );
    final connection = await _checkExternalTorConnectionUsecase.execute();
    if (isClosed || generation != _checkGeneration) return;
    emit(
      state.copyWith(
        connection: connection,
        externalProxyAttempt: connection is TorReady
            ? null
            : state.externalProxyAttempt,
        externalProxyAttemptPort: connection is TorReady
            ? null
            : state.externalProxyAttemptPort,
      ),
    );
  }

  Future<void> refreshSettings() async {
    final generation = ++_settingsGeneration;
    if (!await _loadSettings(generation: generation)) return;
    if (isClosed || generation != _settingsGeneration) return;
    if (state.useTorProxy) await checkConnectionStatus();
  }

  Future<void> onAppResumed() => refreshSettings();

  @override
  Future<void> close() async {
    await _connectionSubscription?.cancel();
    return super.close();
  }
}
