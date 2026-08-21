import 'package:bb_mobile/core/fees/data/fees_datasource.dart';
import 'package:bb_mobile/core/fees/data/fees_repository_impl.dart';
import 'package:bb_mobile/core/fees/data/models/mempool_fees_model.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_settings.dart';
import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatasource extends Mock implements FeesDatasource {}

class _MockMempoolSettingsRepository extends Mock
    implements MempoolSettingsRepository {}

class _MockServerRepository extends Mock implements MempoolServerRepository {}

class _MockAppSettingsRepository extends Mock implements SettingsRepository {}

class _MockTor extends Mock implements Tor {}

class _MockEmbeddedTor extends Mock implements EmbeddedTor {}

class _MockExternalTor extends Mock implements ExternalTor {}

class _MockTorSessions extends Mock implements TorSessions {}

const _fees = MempoolFeesModel(
  fastestFee: 5,
  halfHourFee: 4,
  hourFee: 3,
  economyFee: 2,
  minimumFee: 1,
);

SettingsEntity _appSettings({bool useTorProxy = false, int proxyPort = 9050}) =>
    SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
      useTorProxy: useTorProxy,
      torProxyPort: proxyPort,
    );

void main() {
  late _MockDatasource datasource;
  late _MockMempoolSettingsRepository mempoolSettingsRepository;
  late _MockServerRepository serverRepository;
  late _MockAppSettingsRepository appSettingsRepository;
  late _MockTor tor;
  late _MockEmbeddedTor embeddedTor;
  late _MockExternalTor externalTor;
  late _MockTorSessions torSessions;
  late FeesRepositoryImpl repository;
  late MempoolServerNetwork network;

  setUpAll(() {
    registerFallbackValue(
      MempoolServerNetwork.fromEnvironment(isTestnet: false, isLiquid: false),
    );
    registerFallbackValue(TorProxyEndpoint(host: '127.0.0.1', port: 1));
  });

  setUp(() {
    datasource = _MockDatasource();
    mempoolSettingsRepository = _MockMempoolSettingsRepository();
    serverRepository = _MockServerRepository();
    appSettingsRepository = _MockAppSettingsRepository();
    tor = _MockTor();
    embeddedTor = _MockEmbeddedTor();
    externalTor = _MockExternalTor();
    torSessions = _MockTorSessions();
    repository = FeesRepositoryImpl(
      feesDatasource: datasource,
      mempoolSettingsRepository: mempoolSettingsRepository,
      mempoolServerRepository: serverRepository,
      settingsRepository: appSettingsRepository,
      tor: tor,
    );
    network = MempoolServerNetwork.fromEnvironment(
      isTestnet: false,
      isLiquid: false,
    );
    when(
      () => datasource.fetchBitcoinNetworkFees(
        baseUrl: any(named: 'baseUrl'),
        proxyEndpoint: null,
      ),
    ).thenAnswer((_) async => _fees);
    when(
      () => appSettingsRepository.fetch(),
    ).thenAnswer((_) async => _appSettings());
    when(() => tor.embedded).thenReturn(embeddedTor);
    when(() => tor.external).thenReturn(externalTor);
    when(() => embeddedTor.sessions).thenReturn(torSessions);
  });

  test('uses the BB URL when fee estimation is disabled', () async {
    when(() => mempoolSettingsRepository.fetchByNetwork(network)).thenAnswer(
      (_) async => Ok(
        MempoolSettings.existing(network: network, useForFeeEstimation: false),
      ),
    );

    await repository.getNetworkFees(network: Network.bitcoinMainnet);

    verify(
      () => datasource.fetchBitcoinNetworkFees(
        baseUrl: 'https://mempool.bullbitcoin.com',
        proxyEndpoint: null,
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
    when(() => mempoolSettingsRepository.fetchByNetwork(network)).thenAnswer(
      (_) async => Ok(
        MempoolSettings.existing(network: network, useForFeeEstimation: true),
      ),
    );
    when(
      () => serverRepository.fetchCustomServer(network),
    ).thenAnswer((_) async => Ok(custom));

    await repository.getNetworkFees(network: Network.bitcoinMainnet);

    verify(
      () => datasource.fetchBitcoinNetworkFees(
        baseUrl: 'https://custom.example',
        proxyEndpoint: null,
      ),
    ).called(1);
    verifyNever(() => serverRepository.fetchDefaultServer(any()));
  });

  test('uses the default server when no custom server exists', () async {
    final defaultServer = MempoolServer.existing(
      url: 'default.example',
      network: network,
      isCustom: false,
    );
    when(() => mempoolSettingsRepository.fetchByNetwork(network)).thenAnswer(
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
        proxyEndpoint: null,
      ),
    ).called(1);
  });

  test('propagates settings selection failure without calling HTTP', () async {
    when(
      () => mempoolSettingsRepository.fetchByNetwork(network),
    ).thenAnswer((_) async => const Err(MempoolLoadFailure()));

    await expectLater(
      repository.getNetworkFees(network: Network.bitcoinMainnet),
      throwsA(isA<MempoolFeesException>()),
    );
    verifyNever(
      () => datasource.fetchBitcoinNetworkFees(
        baseUrl: any(named: 'baseUrl'),
        proxyEndpoint: null,
      ),
    );
  });

  test('uses the configured external proxy without a direct attempt', () async {
    final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 9150);
    when(() => appSettingsRepository.fetch()).thenAnswer(
      (_) async => _appSettings(useTorProxy: true, proxyPort: endpoint.port),
    );
    when(() => externalTor.verify(endpoint)).thenAnswer(
      (_) async => TorReady(
        TorRoute(
          source: TorSource.external,
          endpoint: endpoint,
          evidence: TorReadinessEvidence.externalSocksHandshake,
        ),
      ),
    );
    when(
      () => datasource.fetchBitcoinNetworkFees(
        baseUrl: any(named: 'baseUrl'),
        proxyEndpoint: endpoint,
      ),
    ).thenAnswer((_) async => _fees);
    when(() => mempoolSettingsRepository.fetchByNetwork(network)).thenAnswer(
      (_) async => Ok(
        MempoolSettings.existing(network: network, useForFeeEstimation: false),
      ),
    );

    await repository.getNetworkFees(network: Network.bitcoinMainnet);

    verify(
      () => datasource.fetchBitcoinNetworkFees(
        baseUrl: 'https://mempool.bullbitcoin.com',
        proxyEndpoint: endpoint,
      ),
    ).called(1);
    verifyNever(
      () => datasource.fetchBitcoinNetworkFees(
        baseUrl: any(named: 'baseUrl'),
        proxyEndpoint: null,
      ),
    );
    verifyNever(() => torSessions.open());
  });

  test(
    'fails closed when the configured external proxy is unavailable',
    () async {
      final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 9150);
      when(() => appSettingsRepository.fetch()).thenAnswer(
        (_) async => _appSettings(useTorProxy: true, proxyPort: endpoint.port),
      );
      when(() => externalTor.verify(endpoint)).thenAnswer(
        (_) async => const TorUnavailable(
          source: TorSource.external,
          failure: TorExternalProxyUnavailableFailure(),
        ),
      );
      when(() => mempoolSettingsRepository.fetchByNetwork(network)).thenAnswer(
        (_) async => Ok(
          MempoolSettings.existing(
            network: network,
            useForFeeEstimation: false,
          ),
        ),
      );

      await expectLater(
        repository.getNetworkFees(network: Network.bitcoinMainnet),
        throwsA(isA<MempoolFeesException>()),
      );

      verifyNever(
        () => datasource.fetchBitcoinNetworkFees(
          baseUrl: any(named: 'baseUrl'),
          proxyEndpoint: any(named: 'proxyEndpoint'),
        ),
      );
      verifyNever(() => torSessions.open());
    },
  );

  test('retries a failed clearnet request through embedded Tor', () async {
    final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 9250);
    var sessionClosed = false;
    when(() => mempoolSettingsRepository.fetchByNetwork(network)).thenAnswer(
      (_) async => Ok(
        MempoolSettings.existing(network: network, useForFeeEstimation: false),
      ),
    );
    when(
      () => datasource.fetchBitcoinNetworkFees(
        baseUrl: any(named: 'baseUrl'),
        proxyEndpoint: null,
      ),
    ).thenThrow(MempoolFeesException('direct unavailable'));
    when(() => torSessions.open()).thenAnswer(
      (_) async => TorSession(
        endpoint,
        TorTransport.direct,
        () async => sessionClosed = true,
      ),
    );
    when(
      () => datasource.fetchBitcoinNetworkFees(
        baseUrl: any(named: 'baseUrl'),
        proxyEndpoint: endpoint,
      ),
    ).thenAnswer((_) async => _fees);

    final result = await repository.getNetworkFees(
      network: Network.bitcoinMainnet,
    );

    expect(result.fastest.value, 5);
    verifyInOrder([
      () => datasource.fetchBitcoinNetworkFees(
        baseUrl: 'https://mempool.bullbitcoin.com',
        proxyEndpoint: null,
      ),
      () => torSessions.open(),
      () => datasource.fetchBitcoinNetworkFees(
        baseUrl: 'https://mempool.bullbitcoin.com',
        proxyEndpoint: endpoint,
      ),
    ]);
    expect(sessionClosed, isTrue);
  });

  test(
    'routes an onion server through embedded Tor without direct HTTP',
    () async {
      final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 9350);
      var sessionClosed = false;
      final onion = MempoolServer.existing(
        url: 'feesexample.onion',
        network: network,
        isCustom: true,
      );
      when(() => mempoolSettingsRepository.fetchByNetwork(network)).thenAnswer(
        (_) async => Ok(
          MempoolSettings.existing(network: network, useForFeeEstimation: true),
        ),
      );
      when(
        () => serverRepository.fetchCustomServer(network),
      ).thenAnswer((_) async => Ok(onion));
      when(() => torSessions.open()).thenAnswer(
        (_) async => TorSession(
          endpoint,
          TorTransport.direct,
          () async => sessionClosed = true,
        ),
      );
      when(
        () => datasource.fetchBitcoinNetworkFees(
          baseUrl: 'https://feesexample.onion',
          proxyEndpoint: endpoint,
        ),
      ).thenAnswer((_) async => _fees);

      await repository.getNetworkFees(network: Network.bitcoinMainnet);

      verifyNever(
        () => datasource.fetchBitcoinNetworkFees(
          baseUrl: any(named: 'baseUrl'),
          proxyEndpoint: null,
        ),
      );
      verify(
        () => datasource.fetchBitcoinNetworkFees(
          baseUrl: 'https://feesexample.onion',
          proxyEndpoint: endpoint,
        ),
      ).called(1);
      expect(sessionClosed, isTrue);
    },
  );
}
