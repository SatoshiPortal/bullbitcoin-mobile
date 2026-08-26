import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/status/domain/entity/service_status.dart';
import 'package:bb_mobile/core/status/domain/ports/electrum_connectivity_port.dart';
import 'package:bb_mobile/core/status/domain/usecases/check_all_service_status_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Ok;

class _MockElectrumConnectivityPort extends Mock
    implements ElectrumConnectivityPort {}

class _MockExchangeRateRepository extends Mock
    implements ExchangeRateRepository {}

class _MockPayjoinPolicyAccess extends Mock implements PayjoinPolicyAccess {}

class _MockPayjoinDiagnostics extends Mock implements PayjoinDiagnostics {}

class _MockFeesRepository extends Mock implements FeesRepository {}

class _MockEnsureTorReadyUsecase extends Mock
    implements EnsureTorReadyUsecase {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockTor extends Mock implements Tor {}

class _MockExternalTor extends Mock implements ExternalTor {}

SettingsEntity _settings({required bool useTorProxy, int port = 9050}) =>
    SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
      useTorProxy: useTorProxy,
      torProxyPort: port,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(TorProxyEndpoint(host: '127.0.0.1', port: 9050));
    registerFallbackValue(Network.bitcoinMainnet);
    registerFallbackValue(BigInt.zero);
  });
  test('disabled Payjoin is not probed or reported offline', () async {
    final electrum = _MockElectrumConnectivityPort();
    when(
      () => electrum.checkServersInUseAreOnlineForNetwork(any()),
    ).thenAnswer((_) async => true);
    final exchangeRateRepository = _MockExchangeRateRepository();
    when(
      () => exchangeRateRepository.getCurrencyValue(
        amountSat: any(named: 'amountSat'),
        currency: any(named: 'currency'),
      ),
    ).thenAnswer((_) async => throw Exception('Pricer probe failed'));
    final feesRepository = _MockFeesRepository();
    when(
      () => feesRepository.getNetworkFees(network: any(named: 'network')),
    ).thenAnswer((_) async => throw Exception('Mempool probe failed'));
    final payjoinPolicy = _MockPayjoinPolicyAccess();
    final payjoinDiagnostics = _MockPayjoinDiagnostics();
    // Tor is not required for this wallet, so neither the Tor nor the
    // RecoverBull probe is reached — the point of the test is Payjoin.
    when(
      payjoinPolicy.load,
    ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
    final settingsRepository = _MockSettingsRepository();
    final tor = _MockTor();
    final external = _MockExternalTor();
    when(
      () => settingsRepository.fetch(),
    ).thenAnswer((_) async => _settings(useTorProxy: false));
    when(() => tor.external).thenReturn(external);
    final usecase = CheckAllServiceStatusUsecase(
      electrumConnectivityPort: electrum,
      exchangeRateRepository: exchangeRateRepository,
      payjoinPolicy: payjoinPolicy,
      payjoinDiagnostics: payjoinDiagnostics,
      feesRepository: feesRepository,
      ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
      settingsRepository: settingsRepository,
      tor: tor,
    );

    final status = await usecase.execute(network: Network.bitcoinMainnet);

    expect(status.payjoin.status, ServiceStatus.disabled);
    expect(status.payjoin.isOffline, isFalse);
    verifyNever(payjoinDiagnostics.relayHealth);
  });

  test(
    'reports configured external Tor ready without a backup wallet',
    () async {
      final electrum = _MockElectrumConnectivityPort();
      when(
        () => electrum.checkServersInUseAreOnlineForNetwork(any()),
      ).thenAnswer((_) async => true);
      final exchangeRateRepository = _MockExchangeRateRepository();
      when(
        () => exchangeRateRepository.getCurrencyValue(
          amountSat: any(named: 'amountSat'),
          currency: any(named: 'currency'),
        ),
      ).thenAnswer((_) async => throw Exception('Pricer probe failed'));
      final feesRepository = _MockFeesRepository();
      when(
        () => feesRepository.getNetworkFees(network: any(named: 'network')),
      ).thenAnswer((_) async => throw Exception('Mempool probe failed'));
      final payjoinPolicy = _MockPayjoinPolicyAccess();
      when(
        payjoinPolicy.load,
      ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
      final settingsRepository = _MockSettingsRepository();
      final tor = _MockTor();
      final external = _MockExternalTor();
      when(
        () => settingsRepository.fetch(),
      ).thenAnswer((_) async => _settings(useTorProxy: true));
      when(() => tor.external).thenReturn(external);
      when(() => external.verify(any())).thenAnswer(
        (_) async => TorReady(
          TorRoute(
            source: TorSource.external,
            endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 9050),
            evidence: TorReadinessEvidence.externalSocksHandshake,
          ),
        ),
      );
      final usecase = CheckAllServiceStatusUsecase(
        electrumConnectivityPort: electrum,
        exchangeRateRepository: exchangeRateRepository,
        payjoinPolicy: payjoinPolicy,
        payjoinDiagnostics: _MockPayjoinDiagnostics(),
        feesRepository: feesRepository,
        ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
        settingsRepository: settingsRepository,
        tor: tor,
      );

      final status = await usecase.execute(network: Network.bitcoinMainnet);

      expect(status.tor.status, ServiceStatus.online);
    },
  );

  test(
    'reports configured external Tor unavailable without a backup wallet',
    () async {
      final electrum = _MockElectrumConnectivityPort();
      when(
        () => electrum.checkServersInUseAreOnlineForNetwork(any()),
      ).thenAnswer((_) async => true);
      final exchangeRateRepository = _MockExchangeRateRepository();
      when(
        () => exchangeRateRepository.getCurrencyValue(
          amountSat: any(named: 'amountSat'),
          currency: any(named: 'currency'),
        ),
      ).thenAnswer((_) async => throw Exception('Pricer probe failed'));
      final feesRepository = _MockFeesRepository();
      when(
        () => feesRepository.getNetworkFees(network: any(named: 'network')),
      ).thenAnswer((_) async => throw Exception('Mempool probe failed'));
      final payjoinPolicy = _MockPayjoinPolicyAccess();
      when(
        payjoinPolicy.load,
      ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
      final settingsRepository = _MockSettingsRepository();
      final tor = _MockTor();
      final external = _MockExternalTor();
      when(
        () => settingsRepository.fetch(),
      ).thenAnswer((_) async => _settings(useTorProxy: true));
      when(() => tor.external).thenReturn(external);
      when(() => external.verify(any())).thenAnswer(
        (_) async => const TorUnavailable(
          source: TorSource.external,
          failure: TorExternalProxyUnavailableFailure(),
        ),
      );
      final usecase = CheckAllServiceStatusUsecase(
        electrumConnectivityPort: electrum,
        exchangeRateRepository: exchangeRateRepository,
        payjoinPolicy: payjoinPolicy,
        payjoinDiagnostics: _MockPayjoinDiagnostics(),
        feesRepository: feesRepository,
        ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
        settingsRepository: settingsRepository,
        tor: tor,
      );

      final status = await usecase.execute(network: Network.bitcoinMainnet);

      expect(status.tor.status, ServiceStatus.offline);
    },
  );

  test(
    'publishes completed services while Bitcoin Electrum is pending',
    () async {
      final electrum = _MockElectrumConnectivityPort();
      final bitcoinResult = Completer<bool>();
      when(
        () => electrum.checkServersInUseAreOnlineForNetwork(
          Network.bitcoinMainnet,
        ),
      ).thenAnswer((_) => bitcoinResult.future);
      when(
        () => electrum.checkServersInUseAreOnlineForNetwork(
          Network.liquidMainnet,
        ),
      ).thenAnswer((_) async => true);
      final exchangeRateRepository = _MockExchangeRateRepository();
      when(
        () => exchangeRateRepository.getCurrencyValue(
          amountSat: any(named: 'amountSat'),
          currency: any(named: 'currency'),
        ),
      ).thenAnswer((_) async => throw Exception('Pricer probe failed'));
      final feesRepository = _MockFeesRepository();
      when(
        () => feesRepository.getNetworkFees(network: any(named: 'network')),
      ).thenAnswer((_) async => throw Exception('Mempool probe failed'));

      final settingsRepository = _MockSettingsRepository();
      when(
        () => settingsRepository.fetch(),
      ).thenAnswer((_) async => _settings(useTorProxy: false));
      final payjoinPolicy = _MockPayjoinPolicyAccess();
      when(
        payjoinPolicy.load,
      ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));

      final usecase = CheckAllServiceStatusUsecase(
        electrumConnectivityPort: electrum,
        exchangeRateRepository: exchangeRateRepository,
        payjoinPolicy: payjoinPolicy,
        payjoinDiagnostics: _MockPayjoinDiagnostics(),
        feesRepository: feesRepository,
        ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
        settingsRepository: settingsRepository,
        tor: _MockTor(),
      );
      final liquidPublished = Completer<void>();
      var completed = false;

      final resultFuture = usecase.execute(
        network: Network.bitcoinMainnet,
        onUpdate: (status) {
          if (status.liquidElectrum.isOnline &&
              status.bitcoinElectrum.isUnknown &&
              !liquidPublished.isCompleted) {
            liquidPublished.complete();
          }
        },
      )..whenComplete(() => completed = true);

      await liquidPublished.future;
      expect(completed, isFalse);
      bitcoinResult.complete(true);

      final result = await resultFuture;
      expect(result.bitcoinElectrum.isOnline, isTrue);
      expect(result.liquidElectrum.isOnline, isTrue);
      expect(result.lastChecked, isNotNull);
    },
  );

  test('keeps completed service results when another task throws', () async {
    final electrum = _MockElectrumConnectivityPort();
    when(
      () =>
          electrum.checkServersInUseAreOnlineForNetwork(Network.bitcoinMainnet),
    ).thenAnswer((_) async => false);
    when(
      () =>
          electrum.checkServersInUseAreOnlineForNetwork(Network.liquidMainnet),
    ).thenAnswer((_) async => true);
    final exchangeRateRepository = _MockExchangeRateRepository();
    when(
      () => exchangeRateRepository.getCurrencyValue(
        amountSat: any(named: 'amountSat'),
        currency: any(named: 'currency'),
      ),
    ).thenAnswer((_) async => throw Exception('Pricer probe failed'));
    final feesRepository = _MockFeesRepository();
    when(
      () => feesRepository.getNetworkFees(network: any(named: 'network')),
    ).thenAnswer((_) async => throw Exception('Mempool probe failed'));

    final settingsRepository = _MockSettingsRepository();
    when(settingsRepository.fetch).thenThrow(Exception('Tor probe failed'));
    final payjoinPolicy = _MockPayjoinPolicyAccess();
    when(
      payjoinPolicy.load,
    ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));

    final updates = <AllServicesStatus>[];
    final usecase = CheckAllServiceStatusUsecase(
      electrumConnectivityPort: electrum,
      exchangeRateRepository: exchangeRateRepository,
      payjoinPolicy: payjoinPolicy,
      payjoinDiagnostics: _MockPayjoinDiagnostics(),
      feesRepository: feesRepository,
      ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
      settingsRepository: settingsRepository,
      tor: _MockTor(),
    );

    final result = await usecase.execute(
      network: Network.bitcoinMainnet,
      onUpdate: updates.add,
    );

    expect(updates.any((status) => status.liquidElectrum.isOnline), isTrue);
    expect(result.liquidElectrum.isOnline, isTrue);
    expect(result.lastChecked, isNotNull);
  });

  test(
    'reports only the failing Electrum probe as unknown when it throws an Exception',
    () async {
      final electrum = _MockElectrumConnectivityPort();
      when(
        () => electrum.checkServersInUseAreOnlineForNetwork(
          Network.bitcoinMainnet,
        ),
      ).thenAnswer((_) async => true);
      when(
        () => electrum.checkServersInUseAreOnlineForNetwork(
          Network.liquidMainnet,
        ),
      ).thenAnswer((_) async => throw Exception('Electrum probe failed'));
      final exchangeRateRepository = _MockExchangeRateRepository();
      when(
        () => exchangeRateRepository.getCurrencyValue(
          amountSat: any(named: 'amountSat'),
          currency: any(named: 'currency'),
        ),
      ).thenAnswer((_) async => throw Exception('Pricer probe failed'));
      final feesRepository = _MockFeesRepository();
      when(
        () => feesRepository.getNetworkFees(network: any(named: 'network')),
      ).thenAnswer((_) async => throw Exception('Mempool probe failed'));
      final payjoinPolicy = _MockPayjoinPolicyAccess();
      when(
        payjoinPolicy.load,
      ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
      final settingsRepository = _MockSettingsRepository();
      when(
        () => settingsRepository.fetch(),
      ).thenAnswer((_) async => _settings(useTorProxy: false));

      final usecase = CheckAllServiceStatusUsecase(
        electrumConnectivityPort: electrum,
        exchangeRateRepository: exchangeRateRepository,
        payjoinPolicy: payjoinPolicy,
        payjoinDiagnostics: _MockPayjoinDiagnostics(),
        feesRepository: feesRepository,
        ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
        settingsRepository: settingsRepository,
        tor: _MockTor(),
      );

      final result = await usecase.execute(network: Network.bitcoinMainnet);

      expect(result.bitcoinElectrum.status, ServiceStatus.online);
      expect(result.liquidElectrum.status, ServiceStatus.unknown);
    },
  );

  test('propagates a StateError from a service probe', () async {
    final electrum = _MockElectrumConnectivityPort();
    when(
      () =>
          electrum.checkServersInUseAreOnlineForNetwork(Network.bitcoinMainnet),
    ).thenAnswer((_) async => throw StateError('Electrum probe failed'));
    final exchangeRateRepository = _MockExchangeRateRepository();
    when(
      () => exchangeRateRepository.getCurrencyValue(
        amountSat: any(named: 'amountSat'),
        currency: any(named: 'currency'),
      ),
    ).thenAnswer((_) async => throw Exception('Pricer probe failed'));
    final feesRepository = _MockFeesRepository();
    when(
      () => feesRepository.getNetworkFees(network: any(named: 'network')),
    ).thenAnswer((_) async => throw Exception('Mempool probe failed'));
    final payjoinPolicy = _MockPayjoinPolicyAccess();
    when(
      payjoinPolicy.load,
    ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
    final settingsRepository = _MockSettingsRepository();
    when(
      () => settingsRepository.fetch(),
    ).thenAnswer((_) async => _settings(useTorProxy: false));

    final usecase = CheckAllServiceStatusUsecase(
      electrumConnectivityPort: electrum,
      exchangeRateRepository: exchangeRateRepository,
      payjoinPolicy: payjoinPolicy,
      payjoinDiagnostics: _MockPayjoinDiagnostics(),
      feesRepository: feesRepository,
      ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
      settingsRepository: settingsRepository,
      tor: _MockTor(),
    );

    await expectLater(
      usecase.execute(network: Network.bitcoinMainnet),
      throwsA(isA<StateError>()),
    );
  });
}
