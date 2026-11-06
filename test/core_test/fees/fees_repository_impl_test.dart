import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
import 'package:bb_mobile/features/fees/data/regtest_fees_datasource.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/fees/data/fees_datasource.dart';
import 'package:bb_mobile/features/fees/data/fees_repository_impl.dart';
import 'package:bb_mobile/core/fees/data/models/mempool_fees_model.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_settings.dart';
import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _RegtestPort extends ElectrumServersPort {
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

class _MockSettingsRepository extends Mock
    implements MempoolSettingsRepository {}

class _MockServerRepository extends Mock implements MempoolServerRepository {}

const _fees = MempoolFeesModel(
  fastestFee: 5,
  halfHourFee: 4,
  hourFee: 3,
  economyFee: 2,
  minimumFee: 1,
);

void main() {
  late _MockDatasource datasource;
  late _MockSettingsRepository settingsRepository;
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
    settingsRepository = _MockSettingsRepository();
    serverRepository = _MockServerRepository();
    repository = FeesRepositoryImpl(
      feesDatasource: datasource,
      electrumServers: _MockElectrum(),
      mempoolSettingsRepository: settingsRepository,
      mempoolServerRepository: serverRepository,
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
      mempoolSettingsRepository: settingsRepository,
      mempoolServerRepository: serverRepository,
      electrumServers: electrum,
      regtestFeesDatasource: _UnavailableRegtest(),
    );
    await expectLater(
      regtestRepository.getNetworkFees(network: Network.bitcoinRegtest),
      throwsA(isA<MempoolFeesException>()),
    );
    expect(electrum.selected, ElectrumServerNetwork.bitcoinRegtest);
    verifyZeroInteractions(datasource);
    verifyZeroInteractions(settingsRepository);
    verifyZeroInteractions(serverRepository);
  });

  test('uses the BB URL when fee estimation is disabled', () async {
    when(() => settingsRepository.fetchByNetwork(network)).thenAnswer(
      (_) async => Ok(
        MempoolSettings.existing(network: network, useForFeeEstimation: false),
      ),
    );

    await repository.getNetworkFees(network: Network.bitcoinMainnet);

    verify(
      () => datasource.fetchBitcoinNetworkFees(
        baseUrl: 'https://mempool.bullbitcoin.com',
      ),
    ).called(1);
    verifyNever(() => serverRepository.fetchCustomServer(any()));
  });

  test('uses the custom server when fee estimation is enabled', () async {
    final custom = MempoolServer.existing(
      url: 'custom.example',
      network: network,
      isCustom: true,
    );
    when(() => settingsRepository.fetchByNetwork(network)).thenAnswer(
      (_) async => Ok(
        MempoolSettings.existing(network: network, useForFeeEstimation: true),
      ),
    );
    when(
      () => serverRepository.fetchCustomServer(network),
    ).thenAnswer((_) async => Ok(custom));

    await repository.getNetworkFees(network: Network.bitcoinMainnet);

    verify(
      () =>
          datasource.fetchBitcoinNetworkFees(baseUrl: 'https://custom.example'),
    ).called(1);
    verifyNever(() => serverRepository.fetchDefaultServer(any()));
  });

  test('uses the default server when no custom server exists', () async {
    final defaultServer = MempoolServer.existing(
      url: 'default.example',
      network: network,
      isCustom: false,
    );
    when(() => settingsRepository.fetchByNetwork(network)).thenAnswer(
      (_) async => Ok(
        MempoolSettings.existing(network: network, useForFeeEstimation: true),
      ),
    );
    when(
      () => serverRepository.fetchCustomServer(network),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => serverRepository.fetchDefaultServer(network),
    ).thenAnswer((_) async => Ok(defaultServer));

    await repository.getNetworkFees(network: Network.bitcoinMainnet);

    verify(
      () => datasource.fetchBitcoinNetworkFees(
        baseUrl: 'https://default.example',
      ),
    ).called(1);
  });

  test('propagates settings selection failure without calling HTTP', () async {
    when(
      () => settingsRepository.fetchByNetwork(network),
    ).thenAnswer((_) async => const Err(MempoolLoadFailure()));

    await expectLater(
      repository.getNetworkFees(network: Network.bitcoinMainnet),
      throwsA(isA<MempoolFeesException>()),
    );
    verifyNever(
      () => datasource.fetchBitcoinNetworkFees(baseUrl: any(named: 'baseUrl')),
    );
  });
}
