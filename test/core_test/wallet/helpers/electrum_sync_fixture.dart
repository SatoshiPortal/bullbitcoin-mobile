import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

// Public BIP39 test vector; these tests never contact a public server.
const testMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';
const testnetGenesisHeader =
    '01000000'
    '0000000000000000000000000000000000000000000000000000000000000000'
    '3ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a'
    'dae5494dffff001d1aa4ae18';

String scriptHashFor(bdk.Script script) =>
    hex.encode(sha256.convert(script.toBytes()).bytes.reversed.toList());

bdk.Transaction fundingTransaction(bdk.Script script) {
  // A synthetic coinbase avoids unrelated previous-transaction requests.
  final bytes = BytesBuilder()
    ..add([1, 0, 0, 0, 1])
    ..add(Uint8List(32))
    ..add([255, 255, 255, 255, 2, 1, 1, 255, 255, 255, 255, 1]);
  bytes.add(
    (ByteData(8)..setUint64(0, 100000, Endian.little)).buffer.asUint8List(),
  );
  final scriptBytes = script.toBytes();
  bytes
    ..add([scriptBytes.length])
    ..add(scriptBytes)
    ..add([0, 0, 0, 0]);
  return bdk.Transaction(transactionBytes: bytes.toBytes());
}

/// Implements the Electrum calls used by real BDK syncs, including JSON batches.
/// Socket I/O remains on the test isolate while production BDK runs its worker.
class ElectrumSyncServer {
  ElectrumSyncServer(this._listener, this.scriptHash, this.txid, this.rawTx) {
    _listener.listen((socket) {
      connections++;
      _sockets.add(socket);
      unawaited(
        socket.done.then<void>((_) {
          if (!firstDisconnect.isCompleted) firstDisconnect.complete();
        }, onError: (Object _) {}),
      );
      socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) async {
              final request = jsonDecode(line);
              final requests = request is List ? request : [request];
              final gate = historyGate;
              if (gate != null &&
                  requests.any(
                    (item) =>
                        item['method'] == 'blockchain.scripthash.get_history',
                  )) {
                if (!historyStarted.isCompleted) historyStarted.complete();
                await gate.future;
              }
              final response = request is List
                  ? request
                        .map((item) => _answer(item as Map<String, dynamic>))
                        .toList()
                  : _answer(request as Map<String, dynamic>);
              try {
                socket.write('${jsonEncode(response)}\n');
              } on SocketException {
                // A failed RPC can close the client before queued replies flush.
              }
            },
            onError: (Object _) {},
            onDone: () {
              if (!firstDisconnect.isCompleted) firstDisconnect.complete();
            },
          );
    });
  }

  final ServerSocket _listener;
  final String scriptHash;
  final String txid;
  final String rawTx;
  final List<Socket> _sockets = [];
  final List<String> requestedScripts = [];
  int transactionRequests = 0;
  int connections = 0;
  final firstDisconnect = Completer<void>();
  bool failHistory = false;
  Completer<void>? historyGate;
  Completer<void> historyStarted = Completer<void>();

  static Future<ElectrumSyncServer> start(bdk.Script script) async {
    final tx = fundingTransaction(script);
    return ElectrumSyncServer(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
      scriptHashFor(script),
      tx.computeTxid().toString(),
      hex.encode(tx.serialize()),
    );
  }

  ElectrumConnection get connection => ElectrumConnection(
    url: 'tcp://127.0.0.1:${_listener.port}',
    retry: 0,
    timeout: 5,
    stopGap: 20,
    validateDomain: false,
    isCustom: true,
  );

  Map<String, dynamic> _answer(Map<String, dynamic> request) {
    final params = request['params'] as List<dynamic>? ?? [];
    Object? result;
    switch (request['method']) {
      case 'server.version':
        result = ['bull-sync-test', '1.4'];
      case 'blockchain.headers.subscribe':
        result = {'height': 0, 'hex': testnetGenesisHeader};
      case 'blockchain.block.header':
        result = testnetGenesisHeader;
      case 'blockchain.block.headers':
        result = {'count': 1, 'hex': testnetGenesisHeader, 'max': 2016};
      case 'blockchain.scripthash.get_history':
        final requested = params.first as String;
        requestedScripts.add(requested);
        if (failHistory) {
          return {
            'jsonrpc': '2.0',
            'id': request['id'],
            'error': {'code': 1, 'message': 'History temporarily unavailable'},
          };
        }
        result = requested == scriptHash
            ? [
                {'tx_hash': txid, 'height': 0},
              ]
            : [];
      case 'blockchain.transaction.get':
        transactionRequests++;
        if (params.first != txid) {
          return {
            'jsonrpc': '2.0',
            'id': request['id'],
            'error': {'code': -5, 'message': 'Unknown transaction'},
          };
        }
        result = rawTx;
      default:
        return {
          'jsonrpc': '2.0',
          'id': request['id'],
          'error': {
            'code': -32601,
            'message': 'Unsupported method: ${request['method']}',
          },
        };
    }
    return {'jsonrpc': '2.0', 'id': request['id'], 'result': result};
  }

  void disconnectClients() {
    for (final socket in _sockets) {
      socket.destroy();
    }
    _sockets.clear();
  }

  Future<void> close() async {
    final gate = historyGate;
    if (gate != null && !gate.isCompleted) gate.complete();
    for (final socket in _sockets) {
      socket.destroy();
    }
    await _listener.close();
  }
}
