import 'package:electrum/electrum.dart';
import 'package:bb_mobile/features/fees/data/regtest_fees_datasource.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/data/fees_datasource.dart';
import 'package:bb_mobile/features/fees/data/fees_repository_impl.dart';
import 'package:bb_mobile/core/fees/data/models/mempool_fees_model.dart';
import 'package:mempool/mempool.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Err, Ok;
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _RegtestPort extends ElectrumServersPort {
  @override
  Future<bool> hasCustomServers({
    required ElectrumServerNetwork network,
  }) async => false;

  ElectrumServerNetwork? selected;
  @override
  Future<T> runWithFallback<T>({
    required ElectrumServerNetwork network,
    required Future<T> Function(ElectrumConnection) operation,
    bool Function(Object)? isTransient,
  }) {
    selected = network;
    return operation(
      const ElectrumConnection(
        url: 'tcp://127.0.0.1:50000',
        retry: 0,
        timeout: 2,
        stopGap: 20,
        validateDomain: false,
        isCustom: true,
      ),
    );
  }
}

class _UnavailableRegtest extends RegtestFeesDatasource {
  @override
  Future<FeeOptions> fetch(ElectrumConnection connection) async =>
      throw const FormatException('no estimate');
}

class _MockElectrum extends Mock implements ElectrumServersPort {}

class _MockDatasource extends Mock implements FeesDatasource {}

class _MockMempool extends Mock implements Mempool {}

class _MockServers extends Mock implements MempoolServerSettings {}

const _fees = MempoolFeesModel(
  fastestFee: 5,
  halfHourFee: 4,
  hourFee: 3,
  economyFee: 2,
  minimumFee: 1,
);

void main() {
  late _MockDatasource datasource;
  late _MockMempool mempool;
  late _MockServers servers;
  late FeesRepositoryImpl repository;
  setUp(() {
    datasource = _MockDatasource();
    mempool = _MockMempool();
    servers = _MockServers();
    when(() => mempool.servers).thenReturn(servers);
    repository = FeesRepositoryImpl(
      feesDatasource: datasource,
      electrumServers: _MockElectrum(),
      mempool: mempool,
    );
    when(
      () => datasource.fetchBitcoinNetworkFees(baseUrl: any(named: 'baseUrl')),
    ).thenAnswer((_) async => _fees);
  });

  test('regtest estimate failure never falls back to public mempool', () async {
    final electrum = _RegtestPort();
    final regtestRepository = FeesRepositoryImpl(
      feesDatasource: datasource,
      mempool: mempool,
      electrumServers: electrum,
      regtestFeesDatasource: _UnavailableRegtest(),
    );
    await expectLater(
      regtestRepository.getNetworkFees(network: Network.bitcoinRegtest),
      throwsA(isA<MempoolFeesException>()),
    );
    expect(electrum.selected, ElectrumServerNetwork.bitcoinRegtest);
    verifyZeroInteractions(datasource);
    verifyZeroInteractions(servers);
  });

  for (final (network, bitcoin, base) in [
    (
      Network.bitcoinMainnet,
      BitcoinNetwork.mainnet,
      'http://custom.example:8080',
    ),
    (
      Network.bitcoinTestnet,
      BitcoinNetwork.testnet,
      'https://default.example/testnet',
    ),
  ]) {
    test('routes $network estimates through its active Mempool base', () async {
      when(() => servers.activeBase(network: bitcoin))
          .thenAnswer((_) async => Ok(Uri.parse(base)));

      await repository.getNetworkFees(network: network);

      verify(() => datasource.fetchBitcoinNetworkFees(baseUrl: base)).called(1);
      verify(() => servers.activeBase(network: bitcoin)).called(1);
    });
  }

  for (final (kind, label) in [
    (MempoolServerKind.custom, 'custom'),
    (MempoolServerKind.defaultServer, 'default'),
  ]) {
    test('a $label lookup failure stops fees before transport', () async {
      when(() => servers.activeBase(network: BitcoinNetwork.mainnet))
          .thenAnswer((_) async => Err(MempoolLoadFailure(kind)));

      await expectLater(
        repository.getNetworkFees(network: Network.bitcoinMainnet),
        throwsA(
          isA<MempoolFeesException>().having(
            (error) => error.toString(),
            'message',
            contains('Failed to fetch $label mempool server'),
          ),
        ),
      );
      verifyZeroInteractions(datasource);
    });
  }
}
