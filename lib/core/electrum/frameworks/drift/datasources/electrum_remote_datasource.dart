import 'dart:convert';
import 'dart:io' show SecureSocket, Socket;

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:convert/convert.dart';

class ElectrumRemoteDatasource {
  final SqliteDatabase _sqlite;

  ElectrumRemoteDatasource({required this._sqlite});

  Future<TransactionModel> fetch({
    required ElectrumConnection connection,
    required String txid,
  }) async {
    final cachedTransaction = await _sqlite.managers.transactions
        .filter((e) => e.txid(txid))
        .getSingleOrNull();

    if (cachedTransaction != null) return cachedTransaction;

    final txBytes = await _getTransaction(connection, txid);
    final tx = await BitcoinTx.fromBytes(txBytes);

    final txModel = TransactionModel(
      txid: tx.txid,
      version: tx.version,
      size: tx.size.toString(),
      vsize: tx.vsize.toString(),
      locktime: tx.locktime,
      vin: json.encode(tx.vin.map((e) => e.toJson()).toList()),
      vout: json.encode(tx.vout.map((e) => e.toJson()).toList()),
    );
    await _sqlite.into(_sqlite.transactions).insert(txModel);

    return txModel;
  }

  Future<List<int>> _getTransaction(
    ElectrumConnection connection,
    String txid,
  ) async {
    try {
      final timeout = Duration(seconds: connection.timeout);
      // This datasource has no SOCKS implementation. Never silently bypass
      // Tor; the fallback runner will advance to the next server instead.
      if (connection.socks5?.isNotEmpty == true) {
        throw Exception('Proxy-aware Electrum transport unavailable');
      }
      final socket = await _connect(connection);

      final request = {
        'id': 1,
        'method': 'blockchain.transaction.get',
        'params': [txid, false],
      };

      socket.writeln(json.encode(request));

      final lines = utf8.decoder.bind(socket).transform(const LineSplitter());
      final firstLine = await lines.first.timeout(timeout);
      await socket.close();

      return hex.decode(json.decode(firstLine)['result'] as String);
    } catch (e) {
      throw Exception('Electrum RPC error: $e');
    }
  }

  /// Opens the socket described by the resolved [connection] rather than
  /// assuming a CA-validated TLS endpoint.
  ///
  /// A `tcp://` server is reached in the clear, and certificates are validated
  /// according to the user's `validateDomain` setting — the very flag the
  /// BDK/LWK sync obeys — so a personal node with a self-signed certificate
  /// behaves the same on both paths instead of syncing fine but failing here.
  Future<Socket> _connect(ElectrumConnection connection) {
    final uri = _parseUrl(connection.url);
    final timeout = Duration(seconds: connection.timeout);

    if (uri.scheme == 'tcp') {
      return Socket.connect(uri.host, uri.port, timeout: timeout);
    }

    return SecureSocket.connect(
      uri.host,
      uri.port,
      timeout: timeout,
      onBadCertificate: connection.validateDomain ? null : (_) => true,
    );
  }

  /// Servers are stored either with an explicit `ssl://` / `tcp://` scheme or
  /// as a bare `host:port` (how Liquid urls are persisted), which `Uri.parse`
  /// would otherwise read as the scheme. Bare urls default to TLS, matching
  /// the rest of the electrum module.
  Uri _parseUrl(String url) =>
      url.startsWith('ssl://') || url.startsWith('tcp://')
      ? Uri.parse(url)
      : Uri.parse('ssl://$url');
}
