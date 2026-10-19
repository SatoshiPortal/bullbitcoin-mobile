import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';

// A synthetic one-input, one-output transaction. Nothing here comes from a
// wallet; the bytes only need to deserialize and hash deterministically.
String _transactionHex({String lockTime = '00000000'}) =>
    '0100000001${List.filled(32, '00').join()}'
    'ffffffff020101ffffffff01a0860100000000000151$lockTime';

Uint8List _bytes(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

/// A loopback Electrum server scripted with one `blockchain.transaction.get`
/// reply. It answers `server.version` so the client handshake succeeds and
/// rejects every other method.
class _WireServer {
  final ServerSocket _listener;
  final Object? _result;
  final String? _error;
  final _sockets = <Socket>{};
  var queries = 0;

  _WireServer._(this._listener, this._result, this._error) {
    _listener.listen(_serve);
  }

  static Future<_WireServer> start({Object? result, String? error}) async {
    final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    return _WireServer._(listener, result, error);
  }

  ElectrumConnection get connection => ElectrumConnection(
    url: 'tcp://127.0.0.1:${_listener.port}',
    retry: 0,
    timeout: 2,
    stopGap: 20,
    validateDomain: true,
    isCustom: true,
  );

  void _serve(Socket socket) {
    _sockets.add(socket);
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            final request = jsonDecode(line);
            final response = request is List
                ? [for (final r in request) _answer(r as Map)]
                : _answer(request as Map);
            socket.writeln(jsonEncode(response));
          },
          onDone: () => _sockets.remove(socket),
          onError: (Object _) => _sockets.remove(socket),
        );
  }

  Map<String, Object?> _answer(Map<Object?, Object?> request) {
    final id = request['id'];
    switch (request['method']) {
      case 'server.version':
        return {
          'jsonrpc': '2.0',
          'id': id,
          'result': ['wire-fixture', '1.4'],
        };
      case 'blockchain.transaction.get':
        queries++;
        return {
          'jsonrpc': '2.0',
          'id': id,
          if (_error == null) 'result': _result,
          if (_error != null) 'error': {'code': -32603, 'message': _error},
        };
      default:
        return {
          'jsonrpc': '2.0',
          'id': id,
          'error': {'code': -32601, 'message': 'Unsupported fixture method'},
        };
    }
  }

  Future<void> close() async {
    for (final socket in _sockets.toList()) {
      socket.destroy();
    }
    await _listener.close();
  }
}

void main() {
  const datasource = BdkBitcoinBlockchainDatasource();
  late String requested;

  setUpAll(() {
    bdk.ensureInitialized();
    final transaction = bdk.Transaction(
      transactionBytes: _bytes(_transactionHex()),
    );
    requested = transaction.computeTxid().toString();
    transaction.dispose();
  });

  Future<_WireServer> serve({Object? result, String? error}) async {
    final server = await _WireServer.start(result: result, error: error);
    addTearDown(server.close);
    return server;
  }

  group('BdkBitcoinBlockchainDatasource.isTransactionKnown', () {
    test('a matching transaction is visible', () async {
      final server = await serve(result: _transactionHex());
      expect(
        await datasource.isTransactionKnown(
          requested,
          connection: server.connection,
        ),
        isTrue,
      );
      expect(server.queries, 1);
    });

    for (final (name, result) in [
      ('empty bytes', ''),
      ('a truncated transaction', '00'),
      (
        'a transaction with another hash',
        _transactionHex(lockTime: '01000000'),
      ),
    ]) {
      test('$name fails closed instead of counting as visible', () async {
        final server = await serve(result: result);
        await expectLater(
          datasource.isTransactionKnown(
            requested,
            connection: server.connection,
          ),
          throwsA(anything),
        );
        expect(server.queries, 1);
      });
    }

    for (final message in [
      'missing transaction',
      'No such mempool or blockchain transaction. Use gettransaction for '
          'wallet transactions.',
    ]) {
      test('the explicit unknown reply "$message" is absent', () async {
        final server = await serve(error: message);
        expect(
          await datasource.isTransactionKnown(
            requested,
            connection: server.connection,
          ),
          isFalse,
        );
        expect(server.queries, 1);
      });
    }

    for (final message in [
      'No such mempool transaction. Use -txindex or provide a block hash',
      'excessive resource usage',
    ]) {
      test('the protocol error "$message" propagates', () async {
        final server = await serve(error: message);
        await expectLater(
          datasource.isTransactionKnown(
            requested,
            connection: server.connection,
          ),
          throwsA(isA<bdk.ProtocolElectrumException>()),
        );
        expect(server.queries, 1);
      });
    }
  });
}
