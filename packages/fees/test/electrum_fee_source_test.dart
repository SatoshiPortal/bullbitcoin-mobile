import 'dart:convert';
import 'dart:io';

import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mempool/mempool.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

class _Mempool extends Mock implements Mempool {}

void main() {
  for (final (network, targets) in [
    (BitcoinNetwork.mainnet, [1, 6, 24]),
    (BitcoinNetwork.regtest, [1, 3, 6]),
  ]) {
    test(
      'retries missing estimates and uses ${network.name} targets',
      () async {
        final unavailable = await _FeeServer.start(-1);
        final available = await _FeeServer.start(0.00002);
        final mempool = _Mempool();
        final connections = _Connections(network, [
          unavailable.connection,
          available.connection,
        ]);
        final fees = Fees.open(
          connections: connections,
          mempool: mempool,
          readPreference: (_) async => null,
          writePreference: (_, _) async {},
        );

        expect(
          await fees.estimate(network),
          isA<Ok<FeeOptions, FeesFailure>>().having(
            (result) => result.value.fastest.value,
            'fastest',
            2,
          ),
        );
        expect(unavailable.targets, targets);
        expect(available.targets, targets);
        verifyZeroInteractions(mempool);
      },
    );
  }
}

class _Connections implements WalletConnectionPort {
  final Network expected;
  final List<WalletConnection> endpoints;

  _Connections(this.expected, this.endpoints);

  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) async {
    expect(network, expected);
    for (final endpoint in endpoints) {
      final result = await operation(endpoint);
      if (result case Err(:final failure) when mayRetry(failure)) continue;
      return result;
    }
    return const Err(SyncConnectionFailure());
  }
}

/// A local Electrum server that records the real native client's fee targets.
class _FeeServer {
  final ServerSocket socket;
  final double estimate;
  final targets = <int>[];
  final peers = <Socket>{};

  _FeeServer._(this.socket, this.estimate);

  static Future<_FeeServer> start(double estimate) async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final server = _FeeServer._(socket, estimate);
    socket.listen(server._handle);
    addTearDown(() async {
      for (final peer in server.peers) {
        peer.destroy();
      }
      await socket.close();
    });
    return server;
  }

  WalletConnection get connection => WalletConnection(
    url: 'tcp://127.0.0.1:${socket.port}',
    timeout: const Duration(seconds: 2),
    retry: 0,
    stopGap: 20,
    validateDomain: false,
  );

  void _handle(Socket peer) {
    peers.add(peer);
    peer
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final request = jsonDecode(line) as Map<String, dynamic>;
          final method = request['method'];
          if (method == 'blockchain.estimatefee') {
            targets.add((request['params'] as List).single as int);
          }
          peer.writeln(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': request['id'],
              'result': method == 'server.version'
                  ? ['fixture', '1.4']
                  : estimate,
            }),
          );
        }, onDone: () => peers.remove(peer));
  }
}
