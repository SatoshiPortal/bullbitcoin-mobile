import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mempool/mempool.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

class _Mempool extends Mock implements Mempool {}

class _MempoolServers extends Mock implements MempoolServerSettings {}

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
  const key = 'bitcoinFeeSource';
  late _Mempool mempool;
  late _MempoolServers servers;
  late _Connections connections;
  late Map<String, String> stored;
  late bool failRead;
  late bool failWrite;
  late int reads;

  Fees open() => Fees.open(
    connections: connections,
    mempool: mempool,
    readPreference: (key) async {
      reads++;
      if (failRead) throw Exception('Preference unavailable');
      return stored[key];
    },
    writePreference: (key, value) async {
      if (failWrite) throw Exception('Preference unavailable');
      stored[key] = value;
    },
  );

  setUp(() {
    mempool = _Mempool();
    servers = _MempoolServers();
    connections = _Connections();
    stored = {};
    failRead = false;
    failWrite = false;
    reads = 0;
    when(() => mempool.servers).thenReturn(servers);
  });

  test('defaults to Electrum without a recognized saved value', () async {
    final fees = open();
    for (final value in [null, 'future-source', FeeSource.electrum.name]) {
      if (value != null) stored[key] = value;
      expect(
        await fees.readSource(),
        isA<Ok<FeeSource, FeesFailure>>().having(
          (result) => result.value,
          'source',
          FeeSource.electrum,
        ),
      );
    }
  });

  test('stores the source and uses it from a new capability', () async {
    expect(await open().saveSource(FeeSource.mempool), isA<Ok>());
    expect(stored, {key: 'mempool'});
    when(() => servers.activeBase(network: BitcoinNetwork.testnet)).thenAnswer(
      (_) async =>
          const Err(MempoolLoadFailure(MempoolServerKind.defaultServer)),
    );
    final fresh = open();
    expect(
      await fresh.readSource(),
      isA<Ok<FeeSource, FeesFailure>>().having(
        (result) => result.value,
        'source',
        FeeSource.mempool,
      ),
    );
    expect(await fresh.estimate(BitcoinNetwork.testnet), isA<Err>());
    verify(() => servers.activeBase(network: BitcoinNetwork.testnet)).called(1);
    expect(connections.networks, isEmpty);
  });

  test(
    'returns a typed failure when reading or saving the source fails',
    () async {
      final fees = open();
      failRead = true;
      failWrite = true;
      expect(
        await fees.estimate(BitcoinNetwork.mainnet),
        isA<Err<FeeOptions, FeesFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<FeeSourceReadFailure>(),
        ),
      );
      expect(
        await fees.saveSource(FeeSource.mempool),
        isA<Err<void, FeesFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<FeeSourceWriteFailure>(),
        ),
      );
      expect(stored, isEmpty);
      verifyZeroInteractions(mempool);
      expect(connections.networks, isEmpty);
    },
  );

  test(
    'Mempool probe and local networks skip an unavailable preference',
    () async {
      final fees = open();
      failRead = true;
      when(() => servers.activeBase(network: BitcoinNetwork.mainnet))
          .thenAnswer(
            (_) async =>
                const Err(MempoolLoadFailure(MempoolServerKind.custom)),
          );

      expect(
        await fees.estimate(BitcoinNetwork.mainnet, source: FeeSource.mempool),
        isA<Err<FeeOptions, FeesFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<FeeEstimateUnavailableFailure>(),
        ),
      );
      verify(() => servers.activeBase(network: BitcoinNetwork.mainnet))
          .called(1);
      expect(await fees.estimate(BitcoinNetwork.regtest), isA<Err>());
      expect(await fees.estimate(LiquidNetwork.testnet), isA<Ok>());
      expect(await fees.estimate(BitcoinNetwork.signet), isA<Err>());
      expect(reads, 0);
      expect(connections.networks, [BitcoinNetwork.regtest]);
    },
  );
}
