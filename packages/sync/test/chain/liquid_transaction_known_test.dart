import 'dart:convert';
import 'dart:io';

import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:rust_bindings/testing.dart' show BullSdk, BullSdkApi;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

final _txid = 'ab' * 32;

// The pinned LWK library is not built for unit tests: this fake decodes any
// bytes to a transaction whose txid the test chooses.
final class _Sdk implements BullSdkApi {
  String decodedTxid = _txid;

  @override
  lwk.LiquidTransaction lwkApiTransactionLiquidTransactionFromBytes({
    required List<int> txBytes,
  }) => _Transaction(decodedTxid);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

final class _Transaction implements lwk.LiquidTransaction {
  final String _id;

  _Transaction(this._id);

  @override
  String txid() => _id;
  @override
  int version() => 2;
  @override
  int lockTime() => 0;
  @override
  BigInt vsize() => BigInt.from(1000);
  @override
  BigInt weight() => BigInt.from(4000);
  @override
  BigInt fee() => BigInt.from(30);
  @override
  List<lwk.TxInput> getInputs() => const [];
  @override
  List<lwk.TxOutput> getOutputs() => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// A loopback Electrum server answering `blockchain.transaction.get` once.
final class _WireServer {
  final ServerSocket _listener;
  final Map<String, Object?> _reply;
  final _sockets = <Socket>{};

  _WireServer._(this._listener, this._reply) {
    _listener.listen(_serve);
  }

  static Future<_WireServer> start(Map<String, Object?> reply) async {
    final server = _WireServer._(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
      reply,
    );
    addTearDown(server.close);
    return server;
  }

  WalletConnection get connection => WalletConnection(
    url: 'tcp://127.0.0.1:${_listener.port}',
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
        .listen((line) {
          final request = jsonDecode(line);
          final response = request is List
              ? [for (final r in request) _answer(r as Map)]
              : _answer(request as Map);
          socket.writeln(jsonEncode(response));
        }, onDone: () => _sockets.remove(socket));
  }

  Map<String, Object?> _answer(Map<Object?, Object?> request) => {
    'jsonrpc': '2.0',
    'id': request['id'],
    ...switch (request['method']) {
      'server.version' => {
        'result': ['wire-fixture', '1.4'],
      },
      'blockchain.transaction.get' => _reply,
      _ => {
        'error': {'code': -32601, 'message': 'Unsupported method'},
      },
    },
  };

  Future<void> close() async {
    for (final socket in _sockets.toList()) {
      socket.destroy();
    }
    await _listener.close();
  }
}

Map<String, Object?> _error(String message) => {
  'error': {'code': -32603, 'message': message},
};

SyncFailure _err<T>(Result<T, SyncFailure> result) => switch (result) {
  Ok() => throw TestFailure('Unexpected success'),
  Err(:final failure) => failure,
};

void main() {
  final sdk = _Sdk();
  setUpAll(() => BullSdk.initMock(api: sdk));
  tearDownAll(BullSdk.dispose);
  setUp(() => sdk.decodedTxid = _txid);

  test('bytes that decode to the txid are visible', () async {
    final server = await _WireServer.start({'result': '0200'});

    expect(
      await liquidTransactionKnown(_txid, server.connection),
      isA<Ok<bool, SyncFailure>>().having((r) => r.value, 'value', isTrue),
    );
  });

  test('bytes of another transaction fail closed', () async {
    sdk.decodedTxid = 'cd' * 32;
    final server = await _WireServer.start({'result': '0200'});

    expect(
      _err(await liquidTransactionKnown(_txid, server.connection)),
      isA<SyncInvalidTransactionFailure>(),
    );
  });

  test('empty bytes fail closed', () async {
    final server = await _WireServer.start({'result': ''});

    expect(
      _err(await liquidTransactionKnown(_txid, server.connection)),
      isA<SyncInvalidTransactionFailure>(),
    );
  });

  test('the explicit unknown reply is absent', () async {
    final server = await _WireServer.start(_error('missing transaction'));

    expect(
      await liquidTransactionKnown(_txid, server.connection),
      isA<Ok<bool, SyncFailure>>().having((r) => r.value, 'value', isFalse),
    );
  });

  test('an unclassified reply is neither absent nor visible', () async {
    final server = await _WireServer.start(_error('txid not found'));

    expect(
      _err(await liquidTransactionKnown(_txid, server.connection)),
      isA<SyncUnrecognizedReplyFailure>(),
    );
  });

  test('an unreachable server is a connection failure', () async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();

    expect(
      _err(
        await liquidTransactionKnown(
          _txid,
          WalletConnection(
            url: 'tcp://127.0.0.1:$port',
            timeout: const Duration(seconds: 2),
            retry: 0,
            stopGap: 20,
            validateDomain: false,
          ),
        ),
      ),
      isA<SyncConnectionFailure>(),
    );
  });
}
