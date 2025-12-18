import 'dart:convert';
import 'dart:io' show SecureSocket;

import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_server_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:convert/convert.dart';

class ElectrumRemoteDatasource {
  final ElectrumServerModel _server;
  final SqliteDatabase _sqlite;
  late Uri _uri;

  ElectrumRemoteDatasource({
    required ElectrumServerModel server,
    required SqliteDatabase sqlite,
  }) : _server = server,
       _sqlite = sqlite {
    _uri = Uri.parse(_server.url);
  }

  Future<TransactionModel> fetch({required String txid}) async {
    final cachedTransaction = await _sqlite.managers.transactions
        .filter((e) => e.txid(txid))
        .getSingleOrNull();

    if (cachedTransaction != null) return cachedTransaction;

    // If not found in cache, fetch from Electrum
    final txBytes = await _getTransaction(txid);
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

  Future<List<int>> _getTransaction(String txid) async {
    try {
      final socket = await SecureSocket.connect(_uri.host, _uri.port);

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
}
