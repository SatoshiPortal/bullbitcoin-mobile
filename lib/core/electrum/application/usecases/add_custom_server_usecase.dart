import 'package:bb_mobile/core/electrum/application/dtos/requests/add_custom_server_request.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_failure.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class AddCustomServerUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  final ServerStatusPort _serverStatusPort;
  final SettingsRepository _settingsRepository;

  AddCustomServerUsecase({
    required this._electrumServerRepository,
    required this._serverStatusPort,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<ElectrumServerStatus, ElectrumFailure>> execute(
    AddCustomServerRequest request,
  ) async {
    try {
      final server = ElectrumServer.createCustom(
        host: request.host,
        port: request.port,
        network: request.network,
        priority: request.priority,
        enableSsl: request.enableSsl,
      );

      final ElectrumServer? existingServer;
      switch (await _electrumServerRepository.fetchByUrl(server.url)) {
        case Ok(:final value):
          existingServer = value;
        case Err(:final failure):
          return Err(failure);
      }
      if (existingServer != null) {
        return const Err(ElectrumServerAlreadyExistsFailure());
      }

      // Fetch app settings to get Tor configuration
      final appSettings = await _settingsRepository.fetch();
      final useTorProxy = !server.network.isLiquid && appSettings.useTorProxy;

      // Step 1: verify the TCP/SSL socket is reachable
      final socketStatus = await _serverStatusPort.checkSocket(
        url: server.url,
        useTorProxy: useTorProxy,
        torProxyPort: appSettings.torProxyPort,
      );
      if (socketStatus == ElectrumServerStatus.offline) {
        return const Err(ElectrumServerUnreachableFailure());
      }

      // Step 2: verify the server actually serves chain data by fetching a
      // known historical tx (falls back to server.version on testnets).
      // Self-signed certs are tolerated here: this is the user's own server
      // (personal nodes commonly use self-signed certs).
      final protocolStatus = await _serverStatusPort.checkElectrum(
        url: server.url,
        network: server.network,
        skipCertValidation: true,
      );
      if (protocolStatus == ElectrumServerStatus.offline) {
        return const Err(ElectrumServerUnreachableFailure());
      }

      // Both checks passed — persist the server.
      final saveResult = await _electrumServerRepository.save(server);
      return saveResult.map((_) => ElectrumServerStatus.online);
    } catch (e, st) {
      log.severe(
        message: 'Failed to add custom electrum server',
        error: e,
        trace: st,
      );
      return Err(ElectrumUnexpectedFailure(e.toString()));
    }
  }
}
