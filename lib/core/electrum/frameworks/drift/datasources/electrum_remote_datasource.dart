import 'dart:convert';
import 'dart:io' show SecureSocket;
import 'dart:typed_data';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

class ElectrumRemoteDatasource {
  final SqliteDatabase _sqlite;

  ElectrumRemoteDatasource({required this._sqlite});

  Future<TransactionModel> fetch({
    required String serverUrl,
    required String txid,
  }) async {
    final cachedTransaction = await _sqlite.managers.transactions
        .filter((e) => e.txid(txid))
        .getSingleOrNull();

    if (cachedTransaction != null) return cachedTransaction;

    final txBytes = await _getTransaction(Uri.parse(serverUrl), txid);
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

  Future<List<int>> _getTransaction(Uri serverUri, String txid) async {
    try {
      final socket = await SecureSocket.connect(serverUri.host, serverUri.port);

      final request = {
        'id': 1,
        'method': 'blockchain.transaction.get',
        'params': [txid, false],
      };

      socket.writeln(json.encode(request));

      final lines = utf8.decoder.bind(socket).transform(const LineSplitter());
      final firstLine = await lines.first;
      await socket.close();

      return hex.decode(json.decode(firstLine)['result'] as String);
    } catch (e) {
      throw Exception('Electrum RPC error: $e');
    }
  }

  /// Whether the output [txid]:[vout] is currently unspent for the given
  /// [scriptPubkey], via `blockchain.scripthash.listunspent`.
  ///
  /// The Electrum protocol indexes by "scripthash" = the SHA-256 of the
  /// scriptPubkey, reversed. An output is unspent iff it appears in the
  /// server's unspent list for that scripthash. Not cached — spentness is
  /// mutable, unlike a confirmed transaction.
  Future<bool> isOutpointUnspent({
    required String serverUrl,
    required Uint8List scriptPubkey,
    required String txid,
    required int vout,
  }) async {
    final unspent = await _listUnspent(Uri.parse(serverUrl), scriptPubkey);
    for (final entry in unspent) {
      final map = entry as Map<String, dynamic>;
      if (map['tx_hash'] == txid && map['tx_pos'] == vout) return true;
    }
    return false;
  }

  Future<List<dynamic>> _listUnspent(
    Uri serverUri,
    Uint8List scriptPubkey,
  ) async {
    try {
      final digest = sha256.convert(scriptPubkey).bytes;
      final scripthash = hex.encode(digest.reversed.toList());

      final socket = await SecureSocket.connect(serverUri.host, serverUri.port);
      final request = {
        'id': 1,
        'method': 'blockchain.scripthash.listunspent',
        'params': [scripthash],
      };
      socket.writeln(json.encode(request));

      final lines = utf8.decoder.bind(socket).transform(const LineSplitter());
      final firstLine = await lines.first;
      await socket.close();

      return json.decode(firstLine)['result'] as List<dynamic>;
    } catch (e) {
      throw Exception('Electrum RPC error: $e');
    }
  }
}
