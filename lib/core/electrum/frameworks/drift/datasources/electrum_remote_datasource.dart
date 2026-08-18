import 'dart:convert';
import 'dart:io' show Socket;

import 'package:bb_mobile/core/electrum/data/electrum_socket_connector.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_url.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:convert/convert.dart';
import 'package:bull_tor/tor.dart';

class ElectrumRemoteDatasource {
  /// Generous on purpose: this request can be routed through Orbot, where a
  /// circuit to an onion service is built before any byte moves.
  static const _requestTimeout = Duration(seconds: 30);

  final SqliteDatabase _sqlite;
  final ElectrumSocketConnector _socketConnector;

  ElectrumRemoteDatasource({
    required this._sqlite,
    required this._socketConnector,
  });

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
    final serverUri = ElectrumServerUrl(connection.url).uri;
    if (serverUri == null) {
      throw Exception('Electrum RPC error: unusable server address');
    }

    // Empty means "no proxy", which is how persisted settings represent it and
    // how the BDK datasource has always read it. Only a non-empty value that
    // fails to parse is a real misconfiguration worth refusing.
    final socks5 = connection.socks5?.trim();
    final hasProxy = socks5 != null && socks5.isNotEmpty;
    final proxy = hasProxy ? TorProxyEndpoint.tryParse(socks5) : null;
    if (hasProxy && proxy == null) {
      throw Exception('Electrum RPC error: unusable SOCKS5 proxy');
    }

    // An onion circuit is built before the first byte moves, so the user's
    // clearnet timeout is not a sensible ceiling there. Mirrors
    // `ServerStatusAdapter._resolveTimeout`.
    final timeout = proxy == null
        ? Duration(seconds: connection.timeout)
        : _requestTimeout;

    Socket? socket;
    try {
      // Certificates follow the user's `validateDomain` setting — the flag the
      // BDK/LWK sync already obeys — so a personal node with a self-signed
      // certificate behaves the same on both paths.
      socket = await _socketConnector.connect(
        server: serverUri,
        timeout: timeout,
        proxy: proxy,
        allowBadCertificate: !connection.validateDomain,
      );

      final request = {
        'id': 1,
        'method': 'blockchain.transaction.get',
        'params': [txid, false],
      };

      socket.writeln(json.encode(request));

      final lines = utf8.decoder.bind(socket).transform(const LineSplitter());
      final firstLine = await lines.first.timeout(timeout);

      return hex.decode(json.decode(firstLine)['result'] as String);
    } catch (e) {
      throw Exception('Electrum RPC error: $e');
    } finally {
      socket?.destroy();
    }
  }
}
