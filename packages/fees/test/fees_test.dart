import 'package:dio/dio.dart';
import 'package:fees/fees.dart';
import 'package:mempool/mempool.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';
import 'package:flutter_test/flutter_test.dart';

class _Mempool extends Mock implements Mempool {}

class _MempoolServers extends Mock implements MempoolServerSettings {}

class _Http extends Mock implements Dio {}

class _Connections implements WalletConnectionPort {
  final networks = <Network>[];

  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) async {
    networks.add(network);
    return const Err(SyncConnectionFailure());
  }
}

void main() {
  late _Mempool mempool;
  late _MempoolServers servers;
  late _Connections connections;
  late _Http http;
  late List<String> bases;
  late Fees fees;

  setUp(() {
    mempool = _Mempool();
    servers = _MempoolServers();
    connections = _Connections();
    http = _Http();
    bases = [];
    when(() => mempool.servers).thenReturn(servers);
    when(() => http.get<dynamic>('/api/v1/fees/precise')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/api/v1/fees/precise'),
        statusCode: 200,
        data: {
          'fastestFee': 5,
          'halfHourFee': 4,
          'hourFee': 3,
          'economyFee': 2,
          'minimumFee': 0.2,
        },
      ),
    );
    fees = Fees.open(
      connections: connections,
      mempool: mempool,
      readPreference: (_) async => null,
      writePreference: (_, _) async {},
      mempoolHttpClient: (base) {
        bases.add(base);
        return http;
      },
    );
  });

  test('Electrum is the default and its failures never reach HTTP', () async {
    expect(
      await fees.estimate(BitcoinNetwork.testnet),
      isA<Err<FeeOptions, FeesFailure>>(),
    );
    expect(connections.networks, [BitcoinNetwork.testnet]);
    expect(bases, isEmpty);
    verifyZeroInteractions(servers);
  });

  test('regtest stays on Electrum even with a Mempool override', () async {
    expect(
      await fees.estimate(BitcoinNetwork.regtest, source: FeeSource.mempool),
      isA<Err<FeeOptions, FeesFailure>>(),
    );
    expect(connections.networks, [BitcoinNetwork.regtest]);
    expect(bases, isEmpty);
    verifyZeroInteractions(servers);
  });

  test('Liquid uses its relay floor and signet is unavailable', () async {
    expect(
      await fees.estimate(LiquidNetwork.mainnet, source: FeeSource.mempool),
      isA<Ok<FeeOptions, FeesFailure>>().having(
        (result) => result.value.fastest.value,
        'fastest',
        0.1,
      ),
    );
    expect(
      await fees.estimate(BitcoinNetwork.signet, source: FeeSource.mempool),
      isA<Err<FeeOptions, FeesFailure>>(),
    );
    expect(connections.networks, isEmpty);
    expect(bases, isEmpty);
    verifyZeroInteractions(servers);
  });

  for (final (network, base) in [
    (BitcoinNetwork.mainnet, 'http://custom.example:8080'),
    (BitcoinNetwork.testnet, 'https://default.example/testnet'),
  ]) {
    test('Mempool uses the active base for ${network.name}', () async {
      when(() => servers.activeBase(network: network))
          .thenAnswer((_) async => Ok(Uri.parse(base)));

      expect(
        await fees.estimate(network, source: FeeSource.mempool),
        isA<Ok<FeeOptions, FeesFailure>>().having(
          (result) => result.value.fastest.value,
          'fastest',
          5,
        ),
      );
      expect(bases, [base]);
      expect(connections.networks, isEmpty);
      verify(() => servers.activeBase(network: network)).called(1);
    });
  }

  for (final kind in MempoolServerKind.values) {
    test('a ${kind.name} lookup failure stops before HTTP', () async {
      when(() => servers.activeBase(network: BitcoinNetwork.mainnet))
          .thenAnswer((_) async => Err(MempoolLoadFailure(kind)));

      expect(
        await fees.estimate(BitcoinNetwork.mainnet, source: FeeSource.mempool),
        isA<Err<FeeOptions, FeesFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<FeeEstimateUnavailableFailure>(),
        ),
      );
      expect(bases, isEmpty);
      expect(connections.networks, isEmpty);
    });
  }
}
