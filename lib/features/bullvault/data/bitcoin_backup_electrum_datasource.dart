import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/electrum/data/electrum_socket_connector.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_url.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:bull_tor/tor.dart';

/// Finite stock Electrum requests using the same TLS/SOCKS transport as BULL.
/// No production transaction cache or wallet database is needed for discovery.
class BitcoinBackupElectrumDatasource {
  static const maxResponseBytes = 2100000;
  final ElectrumSocketConnector _connector;
  const BitcoinBackupElectrumDatasource(this._connector);

  static Uri validate(ElectrumConnection connection) {
    final uri = ElectrumServerUrl(connection.url).uri;
    if (uri == null ||
        !{'ssl', 'tcp'}.contains(uri.scheme) ||
        !uri.hasPort ||
        uri.port < 1 ||
        uri.port > 65535 ||
        uri.userInfo.isNotEmpty ||
        uri.path.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        connection.timeout < 1 ||
        connection.timeout > 120) {
      throw const FormatException('Invalid Electrum connection');
    }
    final proxy = connection.socks5?.trim();
    if (proxy != null &&
        proxy.isNotEmpty &&
        TorProxyEndpoint.tryParse(proxy) == null) {
      throw const FormatException('Invalid SOCKS connection');
    }
    if (ElectrumServerUrl.isOnionHost(uri.host) &&
        (proxy == null || proxy.isEmpty)) {
      throw const FormatException('Onion connection requires Tor');
    }
    return uri;
  }

  Future<Object?> request(
    ElectrumConnection connection,
    String method,
    List<Object> params,
    DescriptorBackupSession session,
  ) async {
    final uri = validate(connection);
    if (session.isCancelled) throw const FormatException('Cancelled');
    final result = Completer<Object?>();
    Socket? socket;
    StreamSubscription<List<int>>? subscription;
    final timer = Timer(Duration(seconds: connection.effectiveTimeout), () {
      if (!result.isCompleted) {
        result.completeError(TimeoutException('Electrum timeout'));
      }
      socket?.destroy();
    });
    unawaited(
      session.cancelled.then((_) {
        if (!result.isCompleted) {
          result.completeError(const FormatException('Cancelled'));
        }
        socket?.destroy();
      }),
    );
    // Observe completion before connecting, including cancellation during connect.
    final response = result.future;
    final proxy = connection.socks5?.trim();
    final connect = _connector.connect(
      server: uri,
      timeout: Duration(seconds: connection.effectiveTimeout),
      proxy: proxy == null || proxy.isEmpty
          ? null
          : TorProxyEndpoint.tryParse(proxy),
      allowBadCertificate: !connection.validateDomain,
    );
    unawaited(
      connect.then(
        (connected) {
          if (result.isCompleted || session.isCancelled) {
            connected.destroy();
            return;
          }
          socket = connected;
          final buffer = <int>[];
          subscription = connected.listen(
            (chunk) {
              if (result.isCompleted) return;
              if (buffer.length + chunk.length > maxResponseBytes) {
                result.completeError(
                  const FormatException('Electrum response limit'),
                );
                connected.destroy();
                return;
              }
              final newline = chunk.indexOf(10);
              buffer.addAll(newline < 0 ? chunk : chunk.sublist(0, newline));
              if (newline < 0) return;
              try {
                final json = jsonDecode(utf8.decode(buffer));
                if (json is! Map<String, dynamic> ||
                    json['id'] != 1 ||
                    json['error'] != null ||
                    !json.containsKey('result')) {
                  throw const FormatException('Invalid Electrum response');
                }
                result.complete(json['result']);
              } on Exception catch (error) {
                result.completeError(error);
              }
            },
            onError: (Object error) {
              if (!result.isCompleted) result.completeError(error);
            },
            onDone: () {
              if (!result.isCompleted) {
                result.completeError(const SocketException('Electrum closed'));
              }
            },
          );
          connected.writeln(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': 1,
              'method': method,
              'params': params,
            }),
          );
        },
        onError: (Object error) {
          if (!result.isCompleted) result.completeError(error);
        },
      ),
    );
    try {
      return await response;
    } finally {
      timer.cancel();
      socket?.destroy();
      await subscription?.cancel();
    }
  }
}
