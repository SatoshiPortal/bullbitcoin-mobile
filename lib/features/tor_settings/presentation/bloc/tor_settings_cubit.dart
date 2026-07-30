import 'dart:io';
import 'dart:async';

import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/update_tor_settings_usecase.dart';
import 'package:bb_mobile/features/tor_settings/domain/update_tor_transport_mode_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tor/tor.dart';

part 'tor_settings_cubit.freezed.dart';
part 'tor_settings_state.dart';

class TorSettingsCubit extends Cubit<TorSettingsState> {
  TorSettingsCubit({
    required this._getSettingsUsecase,
    required this._updateTorSettingsUsecase,
    required this._updateTorTransportModeUsecase,
    required this._ensureTorReadyUsecase,
    required this._watchTorConnectionUsecase,
    required this._verifyExternalTorUsecase,
  }) : super(const TorSettingsState());

  final GetSettingsUsecase _getSettingsUsecase;
  final UpdateTorSettingsUsecase _updateTorSettingsUsecase;
  final UpdateTorTransportModeUsecase _updateTorTransportModeUsecase;
  final EnsureTorReadyUsecase _ensureTorReadyUsecase;
  final WatchTorConnectionUsecase _watchTorConnectionUsecase;
  final VerifyExternalTorUsecase _verifyExternalTorUsecase;
  StreamSubscription<TorConnectionState>? _connectionSubscription;

  Future<void> init() async {
    await _loadSettings();
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
    await _ensureTorReadyUsecase.execute();
    if (isClosed) return;
    if (state.useTorProxy) await checkConnectionStatus();
  }

  Future<void> _loadSettings() async {
    final settings = await _getSettingsUsecase.execute();
    if (isClosed) return;
    emit(
      state.copyWith(
        useTorProxy: settings.useTorProxy,
        torProxyPort: settings.torProxyPort,
        transportMode: settings.torTransportMode,
        lastSuccessfulTransport: settings.lastSuccessfulTorTransport,
      ),
    );
  }

  Future<void> updateTransportMode(TorTransportMode mode) async {
    emit(state.copyWith(transportMode: mode));
    await _updateTorTransportModeUsecase.execute(mode);
  }

  Future<void> updateTorSettings({
    required bool useTorProxy,
    required int torProxyPort,
  }) async {
    await _updateTorSettingsUsecase.execute(
      useTorProxy: useTorProxy,
      torProxyPort: torProxyPort,
    );
    await _loadSettings();
    if (isClosed) return;
    if (useTorProxy) {
      await checkConnectionStatus();
    } else {
      emit(state.copyWith(connection: const TorStopped(TorSource.external)));
    }
  }

  Future<void> checkConnectionStatus() async {
    if (isClosed || !state.useTorProxy) return;

    emit(
      state.copyWith(
        connection: const TorConnecting(source: TorSource.external),
      ),
    );
    final endpoint = TorProxyEndpoint(
      host: InternetAddress.loopbackIPv4.address,
      port: state.torProxyPort,
    );
    final connection = await _verifyExternalTorUsecase.execute(endpoint);
    if (!isClosed) emit(state.copyWith(connection: connection));
  }

  Future<void> refreshSettings() async {
    await _loadSettings();
    if (state.useTorProxy) await checkConnectionStatus();
  }

  @override
  Future<void> close() async {
    await _connectionSubscription?.cancel();
    return super.close();
  }
}
