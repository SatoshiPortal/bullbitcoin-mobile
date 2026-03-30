import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/electrum/frameworks/socket/datasources/socket_connectivity_datasource.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class ServerStatusAdapter implements ServerStatusPort {
  final SocketConnectivityDatasource _socketDatasource;

  ServerStatusAdapter({required SocketConnectivityDatasource socketDatasource})
    : _socketDatasource = socketDatasource;

  /// Parses a URL string into host, port, and SSL flag.
  /// Returns null if the URL is invalid.
  ({String host, int port, bool useSsl})? _parseUrl(String url) {
    var normalizedUrl = url;
    if (!(url.startsWith('ssl://') || url.startsWith('tcp://'))) {
      normalizedUrl = 'ssl://$url';
    }
    final uri = Uri.parse(normalizedUrl);
    if (uri.host.isEmpty || uri.port == 0) return null;
    return (
      host: uri.host,
      port: uri.port,
      useSsl: normalizedUrl.startsWith('ssl://'),
    );
  }

  @override
  Future<ElectrumServerStatus> checkServerStatus({
    required String url,
    int? timeout,
    bool useTorProxy = false,
    int torProxyPort = 9050,
  }) async {
    try {
      if (url.isEmpty) return ElectrumServerStatus.unknown;

      final uri = _parseUrl(url);
      if (uri == null) return ElectrumServerStatus.offline;

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
      log.severe(
        message: 'Error checking server status',
        error: e,
        trace: StackTrace.current,
      );
      return ElectrumServerStatus.offline;
    }
  }

  @override
  Future<ElectrumServerStatus> checkProtocol({
    required String url,
    int? timeout,
  }) async {
    try {
      if (url.isEmpty) return ElectrumServerStatus.unknown;

      final uri = _parseUrl(url);
      if (uri == null) return ElectrumServerStatus.offline;

      final isOnionAddress = uri.host.endsWith('.onion');
      final effectiveTimeout = timeout ?? (isOnionAddress ? 30 : 5);

      final isAlive = await _socketDatasource.checkProtocol(
        host: uri.host,
        port: uri.port,
        useSsl: uri.useSsl,
        timeoutSeconds: effectiveTimeout,
      );

      return isAlive
          ? ElectrumServerStatus.online
          : ElectrumServerStatus.offline;
    } catch (e) {
      log.severe(
        message: 'Error checking Electrum protocol for $url',
        error: e,
        trace: StackTrace.current,
      );
      return ElectrumServerStatus.offline;
    }
  }
}
