import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/electrum/frameworks/socket/datasources/socket_connectivity_datasource.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class ServerStatusAdapter implements ServerStatusPort {
  final SocketConnectivityDatasource _socketDatasource;

  ServerStatusAdapter({
    required SocketConnectivityDatasource socketDatasource,
  }) : _socketDatasource = socketDatasource;

  @override
  Future<ElectrumServerStatus> checkServerStatus({
    required String url,
    int? timeout,
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

      final isConnectable = await _socketDatasource.checkConnection(
        host: uri.host,
        port: uri.port,
        timeoutSeconds: timeout ?? 5,
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
