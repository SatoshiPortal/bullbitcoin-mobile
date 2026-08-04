import 'dart:io';

import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/update_tor_settings_usecase.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'tor_settings_cubit.freezed.dart';
part 'tor_settings_state.dart';

class TorSettingsCubit extends Cubit<TorSettingsState> {
  TorSettingsCubit({
    required this._getSettingsUsecase,
    required this._updateTorSettingsUsecase,
    required this._verifyExternalTorUsecase,
  }) : super(const TorSettingsState());

  final GetSettingsUsecase _getSettingsUsecase;
  final UpdateTorSettingsUsecase _updateTorSettingsUsecase;
  final VerifyExternalTorUsecase _verifyExternalTorUsecase;

  /// Discards the answer of a check that a newer one has already superseded.
  int _checkGeneration = 0;

  Future<void> init() async {
    await _loadSettings();
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
    emit(state.copyWith(connection: connection));
  }

  Future<void> refreshSettings() async {
    await _loadSettings();
    if (isClosed) return;
    if (state.useTorProxy) await checkConnectionStatus();
  }
}
