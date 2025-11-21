import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/tor/tor_status.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'tor_settings_cubit.freezed.dart';
part 'tor_settings_state.dart';

class TorSettingsCubit extends Cubit<TorSettingsState> {
  TorSettingsCubit({
    required ElectrumSettingsRepository electrumSettingsRepository,
  }) : _electrumSettingsRepository = electrumSettingsRepository,
       super(const TorSettingsState());

  final ElectrumSettingsRepository _electrumSettingsRepository;
  Timer? _statusCheckTimer;

  Future<void> init() async {
    await _loadSettings();
    await checkConnectionStatus();
    _startPeriodicStatusCheck();
  }

  Future<void> _loadSettings() async {
    final settings = await _electrumSettingsRepository.fetchByNetwork(
      ElectrumServerNetwork.bitcoinMainnet,
    );
    emit(
      state.copyWith(
        useTorProxy: settings.useTorProxy,
        torProxyPort: settings.torProxyPort,
      ),
    );
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

    try {
      // Test SOCKS5 proxy functionality by attempting SOCKS5 handshake
      // This verifies both that the port is open AND that our app can use it
      final socket = await Socket.connect(
        '127.0.0.1',
        state.torProxyPort,
        timeout: const Duration(seconds: 3),
      );

      try {
        // Send SOCKS5 handshake: version 5, 1 auth method (no auth)
        socket.add([0x05, 0x01, 0x00]);

        // Wait for SOCKS5 response with timeout
        final response = await socket.first.timeout(
          const Duration(seconds: 3),
          onTimeout: () => throw TimeoutException('SOCKS5 handshake timeout'),
        );

        // Valid SOCKS5 response should be [0x05, 0x00] (version 5, no auth)
        if (response.length >= 2 && response[0] == 0x05) {
          // SOCKS5 proxy responded correctly - connection is working
          await socket.close();
          emit(state.copyWith(status: TorStatus.online));
          log.config(
            'Tor SOCKS5 proxy is online and accessible at 127.0.0.1:${state.torProxyPort}',
          );
        } else {
          // Unexpected response - port is open but not a valid SOCKS5 proxy
          await socket.close();
          emit(state.copyWith(status: TorStatus.unknown));
          log.warning(
            'Port ${state.torProxyPort} is open but not responding as SOCKS5 proxy',
          );
        }
      } catch (e) {
        // SOCKS5 handshake failed - likely app doesn't have permission
        await socket.close();
        emit(state.copyWith(status: TorStatus.offline));
        log.warning(
          'SOCKS5 handshake failed (app may not have permission): $e',
        );
      }
    } on SocketException catch (e) {
      // Connection failed - Tor proxy is not running or not reachable
      emit(state.copyWith(status: TorStatus.offline));
      log.warning('Tor proxy connection failed: $e');
    } on TimeoutException catch (e) {
      // Connection timeout - Tor proxy is not responding
      emit(state.copyWith(status: TorStatus.offline));
      log.warning('Tor proxy connection timeout: $e');
    } catch (e) {
      // Other errors - mark as unknown
      emit(state.copyWith(status: TorStatus.unknown));
      log.severe('Unexpected error checking Tor status: $e');
    }
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
