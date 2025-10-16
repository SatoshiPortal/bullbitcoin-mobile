import 'dart:io';

import 'package:bb_mobile/core/utils/logger.dart';

class SocketConnectivityDatasource {
  const SocketConnectivityDatasource();

  /// Attempts a raw socket connection to verify server reachability
  Future<bool> checkConnection({
    required String host,
    required int port,
    int timeoutSeconds = 5,
  }) async {
    try {
      if (host.isEmpty || port == 0) {
        return false;
      }

      final socket = await Socket.connect(
        host,
        port,
        timeout: Duration(seconds: timeoutSeconds),
      );

      socket.destroy();
      return true;
    } on SocketException catch (e) {
      log.fine('Socket connection failed for $host:$port - $e');
      return false;
    } catch (e) {
      log.severe('Unexpected error checking socket connection: $e');
      return false;
    }
  }
}
