import 'package:electrum/electrum.dart';
import 'package:bb_mobile/features/fees/data/regtest_fees_datasource.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/data/fees_datasource.dart';
import 'package:bb_mobile/features/fees/data/fees_repository_impl.dart';
import 'package:bb_mobile/core/fees/data/models/mempool_fees_model.dart';
import 'package:mempool/mempool.dart';
import 'package:primitives/primitives.dart' show Ok;
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

class _MockServerRepository extends Mock implements Mempool {}

const _fees = MempoolFeesModel(
  fastestFee: 5,
  halfHourFee: 4,
  hourFee: 3,
  economyFee: 2,
  minimumFee: 1,
);

void main() {
  late _MockDatasource datasource;
  late _MockServerRepository serverRepository;
  late FeesRepositoryImpl repository;
  late MempoolServerNetwork network;

  setUpAll(() {
    registerFallbackValue(
      MempoolServerNetwork.fromEnvironment(isTestnet: false, isLiquid: false),
    );
  });

  setUp(() {
    datasource = _MockDatasource();
    serverRepository = _MockServerRepository();
    repository = FeesRepositoryImpl(
      feesDatasource: datasource,
      electrumServers: _MockElectrum(),
      mempool: serverRepository,
    );
    network = MempoolServerNetwork.fromEnvironment(
      isTestnet: false,
      isLiquid: false,
    );
    when(
      () => datasource.fetchBitcoinNetworkFees(baseUrl: any(named: 'baseUrl')),
    ).thenAnswer((_) async => _fees);
  });

  test('regtest estimate failure never falls back to public mempool', () async {
    final electrum = _RegtestPort();
    final regtestRepository = FeesRepositoryImpl(
      feesDatasource: datasource,
      mempool: serverRepository,
      electrumServers: electrum,
      regtestFeesDatasource: _UnavailableRegtest(),
    );
    await expectLater(
      regtestRepository.getNetworkFees(network: Network.bitcoinRegtest),
      throwsA(isA<MempoolFeesException>()),
    );
    expect(electrum.selected, ElectrumServerNetwork.bitcoinRegtest);
    verifyZeroInteractions(datasource);
    verifyZeroInteractions(serverRepository);
  });

  test('uses the custom server when one exists', () async {
    final custom = MempoolServer.existing(
      url: 'custom.example',
      network: network,
      isCustom: true,
    );
    when(() => serverRepository.customServer(network))
        .thenAnswer((_) async => Ok(custom));

    await repository.getNetworkFees(network: Network.bitcoinMainnet);

    verify(
      () =>
          datasource.fetchBitcoinNetworkFees(baseUrl: 'https://custom.example'),
    ).called(1);
    verifyNever(() => serverRepository.defaultServer(any()));
  });

  test('uses the default server when no custom server exists', () async {
    final defaultServer = MempoolServer.existing(
      url: 'default.example',
      network: network,
      isCustom: false,
    );
    when(() => serverRepository.customServer(network))
        .thenAnswer((_) async => const Ok(null));
    when(() => serverRepository.defaultServer(network))
        .thenAnswer((_) async => Ok(defaultServer));

    await repository.getNetworkFees(network: Network.bitcoinMainnet);

    verify(
      () => datasource.fetchBitcoinNetworkFees(
        baseUrl: 'https://default.example',
      ),
    ).called(1);
  });
}
