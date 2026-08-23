import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
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
    required this._ensureTorReadyUsecase,
    required this._watchTorConnectionUsecase,
    required this._verifyExternalTorUsecase,
  }) : super(const TorSettingsState());

  final GetSettingsUsecase _getSettingsUsecase;
  final UpdateTorProxyUsecase _updateTorProxyUsecase;
  final UpdateTorTransportModeUsecase _updateTorTransportModeUsecase;
  final EnsureTorReadyUsecase _ensureTorReadyUsecase;
  final WatchTorConnectionUsecase _watchTorConnectionUsecase;
  final VerifyExternalTorUsecase _verifyExternalTorUsecase;
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
    final ensureTor = _ensureTorReadyUsecase.execute();
    final verifyExternal = state.useTorProxy
        ? checkConnectionStatus()
        : Future<void>.value();
    await Future.wait<void>([ensureTor, verifyExternal]);
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
      ),
    );
    final connection = await _updateTorProxyUsecase.execute(
      useTorProxy: useTorProxy,
      torProxyPort: torProxyPort,
      isCurrent: () => !isClosed && generation == _settingsGeneration,
    );
    if (isClosed || generation != _settingsGeneration) return;
    final accepted = connection is TorReady || !useTorProxy;
    emit(
      state.copyWith(
        useTorProxy: accepted ? useTorProxy : state.useTorProxy,
        torProxyPort: accepted ? torProxyPort : state.torProxyPort,
        connection: state.useTorProxy && !accepted
            ? state.connection
            : connection,
        externalProxyAttempt: accepted ? null : connection,
      ),
    );
  }

  Future<void> checkConnectionStatus() async {
    if (isClosed || !state.useTorProxy) return;

    // Built before the emit on purpose: the constructor rejects an out-of-range
    // port, and the repository layer does not validate what it stores. Emitting
    // Connecting first would leave the card spinning forever on a corrupted or
    // legacy value, with the throw unhandled because `init()` is fire-and-forget.
    final TorProxyEndpoint endpoint;
    try {
      endpoint = TorProxyEndpoint(
        host: InternetAddress.loopbackIPv4.address,
        port: state.torProxyPort,
      );
    } on ArgumentError {
      emit(
        state.copyWith(
          connection: const TorUnavailable(
            source: TorSource.external,
            failure: TorExternalProxyUnavailableFailure(),
          ),
        ),
      );
      return;
    }

    // Two overlapping checks race — change the port while a verify rides out its
    // timeout and the older answer can land last, overwriting a newer one.
    final generation = ++_checkGeneration;
    emit(
      state.copyWith(
        connection: const TorConnecting(source: TorSource.external),
      ),
    );
    final connection = await _verifyExternalTorUsecase.execute(endpoint);
    if (isClosed || generation != _checkGeneration) return;
    emit(
      state.copyWith(
        connection: connection,
        externalProxyAttempt: connection is TorReady
            ? null
            : state.externalProxyAttempt,
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
