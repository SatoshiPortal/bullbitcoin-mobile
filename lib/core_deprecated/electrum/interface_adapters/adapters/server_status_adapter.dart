import 'package:bb_mobile/core_deprecated/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core_deprecated/electrum/frameworks/socket/datasources/socket_connectivity_datasource.dart';
import 'package:bb_mobile/core_deprecated/utils/logger.dart';

class ServerStatusAdapter implements ServerStatusPort {
  final SocketConnectivityDatasource _socketDatasource;

  ServerStatusAdapter({
    required SocketConnectivityDatasource socketDatasource,
  }) : _socketDatasource = socketDatasource;

  @override
  Future<ElectrumServerStatus> checkServerStatus({
    required String url,
    int? timeout,
    bool useTorProxy = false,
    int torProxyPort = 9050,
  }) async {
    try {
      if (url.isEmpty) {
        return ElectrumServerStatus.unknown;
      }

      // Normalize URL - ensure it has a protocol prefix
      // TODO: Remove this once lwk accepts ssl:// prefix
      // TODO: Eventually we should properly handle ssl prefix
      // If not specified, assume ssl
      // If specified, use it (tcp or ssl)
      var normalizedUrl = url;
      if (!(url.startsWith('ssl://') || url.startsWith('tcp://'))) {
        normalizedUrl = 'ssl://$url';
      }

      final uri = Uri.parse(normalizedUrl);
      if (uri.host.isEmpty || uri.port == 0) {
        return ElectrumServerStatus.offline;
      }

      // Onion addresses need longer timeouts due to Tor circuit building
      // Default: 5 seconds for clearnet, 30 seconds for onion addresses
      final isOnionAddress = uri.host.endsWith('.onion');
      final effectiveTimeout = timeout ?? (isOnionAddress ? 30 : 5);

      final isConnectable = await _socketDatasource.checkConnection(
        host: uri.host,
        port: uri.port,
        timeoutSeconds: effectiveTimeout,
        useTorProxy: useTorProxy,
        torProxyPort: torProxyPort,
      );

      return isConnectable
          ? ElectrumServerStatus.online
          : ElectrumServerStatus.offline;
    } catch (e) {
      log.severe('Error checking server status for $url: $e');
      return ElectrumServerStatus.offline;
    }
  }
}
