import 'dart:convert';
import 'dart:io' show SecureSocket;

import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_server_model.dart';
import 'package:convert/convert.dart';

class ElectrumRemoteDatasource {
  final ElectrumServerModel _server;
  late Uri _uri;

  ElectrumRemoteDatasource({required ElectrumServerModel server})
    : _server = server {
    _uri = Uri.parse(_server.url);
  }

  Future<List<int>> getTransaction(String txid) async {
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
