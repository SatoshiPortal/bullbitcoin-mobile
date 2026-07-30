import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/electrum/data/electrum_socket_connector.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_url.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:convert/convert.dart';
import 'package:tor/tor.dart';

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
    required String serverUrl,
    required String txid,
    String? socks5,
  }) async {
    final cachedTransaction = await _sqlite.managers.transactions
        .filter((e) => e.txid(txid))
        .getSingleOrNull();

    if (cachedTransaction != null) return cachedTransaction;

    final serverUri = ElectrumServerUrl(serverUrl).uri;
    if (serverUri == null) {
      throw Exception('Electrum RPC error: unusable server address $serverUrl');
    }

    final txBytes = await _getTransaction(serverUri, txid, socks5: socks5);
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
    Uri serverUri,
    String txid, {
    String? socks5,
  }) async {
    final proxy = socks5 == null ? null : TorProxyEndpoint.tryParse(socks5);
    if (socks5 != null && proxy == null) {
      throw Exception('Electrum RPC error: unusable SOCKS5 proxy');
    }

    Socket? socket;
    try {
      socket = await _socketConnector.connect(
        server: serverUri,
        timeout: _requestTimeout,
        proxy: proxy,
      );

      final request = {
        'id': 1,
        'method': 'blockchain.transaction.get',
        'params': [txid, false],
      };

      socket.writeln(json.encode(request));

      final lines = utf8.decoder.bind(socket).transform(const LineSplitter());
      final firstLine = await lines.first.timeout(_requestTimeout);

      return hex.decode(json.decode(firstLine)['result'] as String);
    } catch (e) {
      throw Exception('Electrum RPC error: $e');
    } finally {
      socket?.destroy();
    }
  }
}
