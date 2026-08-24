import 'dart:async';

import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/tor/configured_external_tor.dart';
import 'package:bb_mobile/core/tor/resolve_configured_external_tor_usecase.dart';
import 'package:bb_mobile/features/tor_settings/domain/update_tor_proxy_usecase.dart';
import 'package:bb_mobile/features/tor_settings/domain/update_tor_transport_mode_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:bull_tor/tor.dart';

part 'tor_settings_cubit.freezed.dart';
part 'tor_settings_state.dart';

class TorSettingsCubit extends Cubit<TorSettingsState> {
  TorSettingsCubit({
    required this._getSettingsUsecase,
    required this._updateTorProxyUsecase,
    required this._updateTorTransportModeUsecase,
    required this._watchTorConnectionUsecase,
    required this._resolveConfiguredExternalTorUsecase,
  }) : super(const TorSettingsState());

  final GetSettingsUsecase _getSettingsUsecase;
  final UpdateTorProxyUsecase _updateTorProxyUsecase;
  final UpdateTorTransportModeUsecase _updateTorTransportModeUsecase;
  final WatchTorConnectionUsecase _watchTorConnectionUsecase;
  final ResolveConfiguredExternalTorUsecase
  _resolveConfiguredExternalTorUsecase;
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
    _connectionSubscription ??= _watchTorConnectionUsecase.execute().listen((
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
    final settings = await _getSettingsUsecase.execute();
    if (isClosed || (generation != null && generation != _settingsGeneration)) {
      return false;
    }
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
    final resolved = await _resolveConfiguredExternalTorUsecase.execute();
    if (isClosed || generation != _checkGeneration) return;
    final connection = switch (resolved) {
      ConfiguredExternalTorReady(:final route) => TorReady(route),
      ConfiguredExternalTorUnavailable(:final failure) => TorUnavailable(
        source: TorSource.external,
        failure: failure,
      ),
      ConfiguredExternalTorDisabled() => const TorUnavailable(
        source: TorSource.external,
        failure: TorExternalProxyUnavailableFailure(),
      ),
    };
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
