import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

import '../support/connections.dart';

// A synthetic one-input, one-output transaction. Nothing here comes from a
// wallet; the bytes only need to deserialize and hash deterministically.
String _transactionHex({String lockTime = '00000000'}) =>
    '0100000001${'00' * 32}ffffffff020101ffffffff01a0860100000000000151'
    '$lockTime';

List<int> _bytes(String hex) => [
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
];

// Bitcoin's genesis block header: any valid 80-byte header will do.
const _header =
    '0100000000000000000000000000000000000000000000000000000000000000000000'
    '003ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a29ab'
    '5f49ffff001d1dac2b7c';

/// A loopback Electrum server with one scripted reply per method.
final class _WireServer {
  final ServerSocket _listener;
  final Map<String, Object> replies;
  final _sockets = <Socket>{};
  final calls = <String>[];

  _WireServer._(this._listener, this.replies) {
    _listener.listen(_serve);
  }

  static Future<_WireServer> start(Map<String, Object> replies) async {
    final server = _WireServer._(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
      replies,
    );
    addTearDown(server.close);
    return server;
  }

  String get url => 'tcp://127.0.0.1:${_listener.port}';

  WalletConnection get connection => WalletConnection(
    url: url,
    timeout: const Duration(seconds: 2),
    retry: 0,
    stopGap: 20,
    validateDomain: false,
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
    final method = request['method'] as String;
    calls.add(method);
    final reply = switch (method) {
      'server.version' => const _Result(['wire-fixture', '1.4']),
      'blockchain.headers.subscribe' => const _Result({
        'hex': _header,
        'height': 0,
      }),
      _ => replies[method] ?? const _Error(-32601, 'Unsupported method'),
    };
    return {
      'jsonrpc': '2.0',
      'id': request['id'],
      if (reply case _Result(:final value)) 'result': value,
      if (reply case _Error(:final code, :final message))
        'error': {'code': code, 'message': message},
    };
  }

  Future<void> close() async {
    for (final socket in _sockets.toList()) {
      socket.destroy();
    }
    await _listener.close();
  }
}

final class _Result {
  final Object value;
  const _Result(this.value);
}

final class _Error {
  final int code;
  final String message;
  const _Error(this.code, this.message);
}

/// A loopback port nothing listens on.
Future<String> _closedUrl() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return 'tcp://127.0.0.1:$port';
}

SyncFailure _err<T>(Result<T, SyncFailure> result) => switch (result) {
  Ok() => throw TestFailure('Unexpected success'),
  Err(:final failure) => failure,
};

void main() {
  late String txid;

  setUpAll(() {
    final transaction = bdk.Transaction(
      transactionBytes: Uint8List.fromList(_bytes(_transactionHex())),
    );
    txid = transaction.computeTxid().toString();
    transaction.dispose();
  });

  group('broadcastBitcoinTransaction', () {
    Future<Result<String, SyncFailure>> broadcast(
      FixtureConnections connections, {
      List<int>? transaction,
    }) => broadcastBitcoinTransaction(
      transaction ?? _bytes(_transactionHex()),
      network: BitcoinNetwork.regtest,
      connections: connections,
    );

    test('an accepted transaction returns its locally computed txid', () async {
      final server = await _WireServer.start({
        'blockchain.transaction.broadcast': _Result('ff' * 32),
      });
      final result = await broadcast(FixtureConnections([server.url]));
      expect(result, isA<Ok<String, SyncFailure>>());
      expect((result as Ok<String, SyncFailure>).value, txid);
      expect(server.calls, contains('blockchain.transaction.broadcast'));
    });

    test('an undecodable transaction reaches no server', () async {
      final connections = FixtureConnections(['tcp://127.0.0.1:1']);
      expect(
        _err(await broadcast(connections, transaction: const [1, 2, 3])),
        isA<SyncInvalidTransactionFailure>(),
      );
      expect(connections.attempts, 0);
    });

    for (final (name, message, expected) in [
      (
        '-26',
        'sendrawtransaction RPC error -26: min relay fee not met',
        isA<SyncBroadcastRejectedFailure>(),
      ),
      (
        '-27',
        'sendrawtransaction RPC error -27: Transaction outputs already in utxo set',
        isA<SyncAlreadyInChainFailure>(),
      ),
      (
        'an unclassified error',
        'excessive resource usage',
        isA<SyncOutcomeUnknownFailure>(),
      ),
    ]) {
      test('a server answering $name', () async {
        final server = await _WireServer.start({
          'blockchain.transaction.broadcast': _Error(2, message),
        });
        expect(
          _err(await broadcast(FixtureConnections([server.url]))),
          expected,
        );
      });
    }

    test('every server rejecting is a rejection', () async {
      final rejecting = {
        'blockchain.transaction.broadcast': const _Error(
          -26,
          'txn-mempool-conflict',
        ),
      };
      final first = await _WireServer.start(rejecting);
      final second = await _WireServer.start(rejecting);
      final connections = FixtureConnections([first.url, second.url]);
      expect(
        _err(await broadcast(connections)),
        isA<SyncBroadcastRejectedFailure>(),
      );
      expect(connections.attempts, 2);
    });

    test('a rejection after an unreachable server stays unknown', () async {
      final rejecting = await _WireServer.start({
        'blockchain.transaction.broadcast': const _Error(-26, 'conflict'),
      });
      final connections = FixtureConnections([
        await _closedUrl(),
        rejecting.url,
      ]);
      expect(
        _err(await broadcast(connections)),
        isA<SyncOutcomeUnknownFailure>(),
      );
      expect(connections.attempts, 2);
    });

    test('a later server accepting wins over an earlier failure', () async {
      final accepting = await _WireServer.start({
        'blockchain.transaction.broadcast': _Result('ff' * 32),
      });
      final connections = FixtureConnections([
        await _closedUrl(),
        accepting.url,
      ]);
      final result = await broadcast(connections);
      expect((result as Ok<String, SyncFailure>).value, txid);
    });

    test('unreachable servers are a connection failure', () async {
      final connections = FixtureConnections([await _closedUrl()]);
      expect(_err(await broadcast(connections)), isA<SyncConnectionFailure>());
    });
  });

  group('broadcastBitcoinTransactionTo', () {
    test('one server accepting returns the local txid', () async {
      final server = await _WireServer.start({
        'blockchain.transaction.broadcast': _Result('ff' * 32),
      });
      final result = await broadcastBitcoinTransactionTo(
        server.connection,
        _bytes(_transactionHex()),
      );
      expect((result as Ok<String, SyncFailure>).value, txid);
    });

    test('one server rejecting is a rejection, with no fallback', () async {
      final server = await _WireServer.start({
        'blockchain.transaction.broadcast': const _Error(-26, 'conflict'),
      });
      expect(
        _err(
          await broadcastBitcoinTransactionTo(
            server.connection,
            _bytes(_transactionHex()),
          ),
        ),
        isA<SyncBroadcastRejectedFailure>(),
      );
      expect(
        server.calls.where((c) => c == 'blockchain.transaction.broadcast'),
        hasLength(1),
      );
    });

    test('undecodable bytes reach no server', () async {
      final server = await _WireServer.start(const {});
      expect(
        _err(await broadcastBitcoinTransactionTo(server.connection, const [0])),
        isA<SyncInvalidTransactionFailure>(),
      );
      expect(server.calls, isEmpty);
    });
  });

  group('bitcoinTransactionKnown', () {
    test('a matching transaction is visible', () async {
      final server = await _WireServer.start({
        'blockchain.transaction.get': _Result(_transactionHex()),
      });
      expect(
        await bitcoinTransactionKnown(txid, server.connection),
        isA<Ok<bool, SyncFailure>>().having((r) => r.value, 'value', isTrue),
      );
    });

    for (final (name, reply) in [
      ('empty bytes', ''),
      ('a truncated transaction', '00'),
      (
        'a transaction with another hash',
        _transactionHex(lockTime: '01000000'),
      ),
    ]) {
      test('$name fails closed instead of counting as visible', () async {
        final server = await _WireServer.start({
          'blockchain.transaction.get': _Result(reply),
        });
        expect(
          _err(await bitcoinTransactionKnown(txid, server.connection)),
          isA<SyncInvalidTransactionFailure>(),
        );
      });
    }

    for (final message in [
      'missing transaction',
      'No such mempool or blockchain transaction. Use gettransaction for '
          'wallet transactions.',
    ]) {
      test('the explicit unknown reply "$message" is absent', () async {
        final server = await _WireServer.start({
          'blockchain.transaction.get': _Error(-32603, message),
        });
        expect(
          await bitcoinTransactionKnown(txid, server.connection),
          isA<Ok<bool, SyncFailure>>().having((r) => r.value, 'value', isFalse),
        );
      });
    }

    for (final message in [
      'No such mempool transaction. Use -txindex or provide a block hash',
      'txid not found',
      'excessive resource usage',
    ]) {
      test('the reply "$message" is neither absent nor visible', () async {
        final server = await _WireServer.start({
          'blockchain.transaction.get': _Error(-32603, message),
        });
        expect(
          _err(await bitcoinTransactionKnown(txid, server.connection)),
          isA<SyncUnrecognizedReplyFailure>(),
        );
      });
    }

    test('an unreachable server is a connection failure', () async {
      final connection = WalletConnection(
        url: await _closedUrl(),
        timeout: const Duration(seconds: 2),
        retry: 0,
        stopGap: 20,
        validateDomain: false,
      );
      expect(
        _err(await bitcoinTransactionKnown(txid, connection)),
        isA<SyncConnectionFailure>(),
      );
    });
  });

  group('probeBitcoinServer', () {
    test('a server answering headers is reachable', () async {
      final server = await _WireServer.start(const {});
      expect(
        await probeBitcoinServer(server.connection),
        isA<Ok<void, SyncFailure>>(),
      );
      expect(server.calls, contains('blockchain.headers.subscribe'));
    });

    test('a server without the known transaction fails the probe', () async {
      final server = await _WireServer.start({
        'blockchain.transaction.get': const _Error(
          -32603,
          'missing transaction',
        ),
      });
      expect(
        _err(await probeBitcoinServer(server.connection, knownTxid: txid)),
        isA<SyncConnectionFailure>(),
      );
    });

    test('a server with the known transaction passes the probe', () async {
      final server = await _WireServer.start({
        'blockchain.transaction.get': _Result(_transactionHex()),
      });
      expect(
        await probeBitcoinServer(server.connection, knownTxid: txid),
        isA<Ok<void, SyncFailure>>(),
      );
    });
  });

  group('estimateBitcoinFees', () {
    test('returns the server estimate for each target, in order', () async {
      final server = await _WireServer.start({
        'blockchain.estimatefee': const _Result(0.00002),
      });
      final result = await estimateBitcoinFees(
        server.connection,
        targets: const [1, 3, 6],
      );
      expect(
        result,
        isA<Ok<List<double>, SyncFailure>>().having((r) => r.value, 'value', [
          0.00002,
          0.00002,
          0.00002,
        ]),
      );
      expect(
        server.calls.where((call) => call == 'blockchain.estimatefee'),
        hasLength(3),
      );
    });

    test('a server error is a connection failure', () async {
      final server = await _WireServer.start(const {});
      expect(
        _err(await estimateBitcoinFees(server.connection, targets: const [1])),
        isA<SyncConnectionFailure>(),
      );
    });
  });
}
