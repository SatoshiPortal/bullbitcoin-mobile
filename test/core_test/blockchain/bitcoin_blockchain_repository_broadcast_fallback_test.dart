import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/data/repository/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/electrum/domain/electrum_fallback_runner.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBdkBitcoinBlockchainDatasource extends Mock
    implements BdkBitcoinBlockchainDatasource {}

/// A minimal [ElectrumServersPort] that runs the real [runElectrumFallback]
/// over two fixed servers — enough to prove the `isTransient` classifier
/// [BitcoinBlockchainRepository] passes in actually reaches (and controls)
/// the fallback loop, without pulling in the real server-resolution adapter
/// and its repositories.
class _FakeTwoServerPort implements ElectrumServersPort {
  static const servers = [
    ElectrumConnection(
      url: 'server-a',
      retry: 1,
      timeout: 1,
      stopGap: 1,
      validateDomain: false,
      isCustom: false,
    ),
    ElectrumConnection(
      url: 'server-b',
      retry: 1,
      timeout: 1,
      stopGap: 1,
      validateDomain: false,
      isCustom: false,
    ),
  ];

  @override
  Future<T> runWithFallback<T>({
    required ElectrumServerNetwork network,
    required Future<T> Function(ElectrumConnection connection) operation,
    bool Function(Object error)? isTransient,
  }) {
    return runElectrumFallback<ElectrumConnection, T>(
      servers: servers,
      urlOf: (c) => c.url,
      isCustomOf: (c) => c.isCustom,
      operation: operation,
      isTransient: isTransient,
    );
  }
}

void main() {
  late _MockBdkBitcoinBlockchainDatasource datasource;
  late BitcoinBlockchainRepository repository;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(
      const ElectrumConnection(
        url: 'fallback',
        retry: 1,
        timeout: 1,
        stopGap: 1,
        validateDomain: false,
        isCustom: false,
      ),
    );
  });

  setUp(() {
    datasource = _MockBdkBitcoinBlockchainDatasource();
    repository = BitcoinBlockchainRepository(
      blockchainDatasource: datasource,
      serversPort: _FakeTwoServerPort(),
    );
  });

  group('broadcastTransaction', () {
    test('a permanent mempool rejection from the first server is rethrown '
        'unchanged, without ever trying the second server', () async {
      final tried = <String>[];
      when(
        () => datasource.broadcastTransaction(
          any(),
          connection: any(named: 'connection'),
        ),
      ).thenAnswer((invocation) async {
        final connection =
            invocation.namedArguments[#connection] as ElectrumConnection;
        tried.add(connection.url);
        throw Exception('missingorspent (code 64)');
      });

      await expectLater(
        repository.broadcastTransaction([1, 2, 3], isTestnet: true),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('missingorspent'),
          ),
        ),
      );
      expect(tried, ['server-a']);
    });

    test('a transient error from the first server falls back to the second, '
        'which then succeeds', () async {
      final tried = <String>[];
      when(
        () => datasource.broadcastTransaction(
          any(),
          connection: any(named: 'connection'),
        ),
      ).thenAnswer((invocation) async {
        final connection =
            invocation.namedArguments[#connection] as ElectrumConnection;
        tried.add(connection.url);
        if (connection.url == 'server-a') {
          throw Exception('connection refused');
        }
        return 'txid-success';
      });

      final txId = await repository.broadcastTransaction([
        1,
        2,
        3,
      ], isTestnet: true);

      expect(txId, 'txid-success');
      expect(tried, ['server-a', 'server-b']);
    });
  });

  group('broadcastPsbt', () {
    test('a permanent policy rejection (dust) is rethrown unchanged, without '
        'ever trying the second server', () async {
      final tried = <String>[];
      when(
        () => datasource.broadcastPsbt(
          any(),
          connection: any(named: 'connection'),
        ),
      ).thenAnswer((invocation) async {
        final connection =
            invocation.namedArguments[#connection] as ElectrumConnection;
        tried.add(connection.url);
        throw Exception('dust');
      });

      await expectLater(
        repository.broadcastPsbt('finalized-psbt', isTestnet: true),
        throwsA(isA<Exception>()),
      );
      expect(tried, ['server-a']);
    });

    test('a transient error from the first server falls back to the second, '
        'which then succeeds', () async {
      final tried = <String>[];
      when(
        () => datasource.broadcastPsbt(
          any(),
          connection: any(named: 'connection'),
        ),
      ).thenAnswer((invocation) async {
        final connection =
            invocation.namedArguments[#connection] as ElectrumConnection;
        tried.add(connection.url);
        if (connection.url == 'server-a') {
          throw Exception('timeout');
        }
        return 'txid-success';
      });

      final txId = await repository.broadcastPsbt(
        'finalized-psbt',
        isTestnet: true,
      );

      expect(txId, 'txid-success');
      expect(tried, ['server-a', 'server-b']);
    });
  });
}
