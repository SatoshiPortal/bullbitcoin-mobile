import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';

class ElectrumService {
  final String host;
  final int port;

  ElectrumService({required this.host, this.port = 50001});

  Future<List<int>> getTransaction(String txid) async {
    try {
      final socket = await SecureSocket.connect(host, port);

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
