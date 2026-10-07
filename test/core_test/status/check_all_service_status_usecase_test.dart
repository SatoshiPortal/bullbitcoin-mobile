import 'dart:async';

import 'package:bb_mobile/core/price/domain/repositories/bitcoin_price_repository.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/status/domain/entity/service_status.dart';
import 'package:bb_mobile/core/status/domain/ports/electrum_connectivity_port.dart';
import 'package:bb_mobile/core/status/domain/usecases/check_all_service_status_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Ok;

class _MockElectrumConnectivityPort extends Mock
    implements ElectrumConnectivityPort {}

class _MockBitcoinPriceRepository extends Mock
    implements BitcoinPriceRepository {}

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

TorRoute _route(TorSource source) => TorRoute(
  source: source,
  endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 9050),
  evidence: source == TorSource.embedded
      ? TorReadinessEvidence.embeddedBootstrap
      : TorReadinessEvidence.externalSocksHandshake,
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
    final bitcoinPriceRepository = _MockBitcoinPriceRepository();
    when(
      () => bitcoinPriceRepository.getCurrencyValue(
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
      bitcoinPriceRepository: bitcoinPriceRepository,
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
      final bitcoinPriceRepository = _MockBitcoinPriceRepository();
      when(
        () => bitcoinPriceRepository.getCurrencyValue(
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
        bitcoinPriceRepository: bitcoinPriceRepository,
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
      final bitcoinPriceRepository = _MockBitcoinPriceRepository();
      when(
        () => bitcoinPriceRepository.getCurrencyValue(
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
        bitcoinPriceRepository: bitcoinPriceRepository,
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
      final bitcoinPriceRepository = _MockBitcoinPriceRepository();
      when(
        () => bitcoinPriceRepository.getCurrencyValue(
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
        bitcoinPriceRepository: bitcoinPriceRepository,
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
    final bitcoinPriceRepository = _MockBitcoinPriceRepository();
    when(
      () => bitcoinPriceRepository.getCurrencyValue(
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
      bitcoinPriceRepository: bitcoinPriceRepository,
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
      final bitcoinPriceRepository = _MockBitcoinPriceRepository();
      when(
        () => bitcoinPriceRepository.getCurrencyValue(
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
        bitcoinPriceRepository: bitcoinPriceRepository,
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
    final bitcoinPriceRepository = _MockBitcoinPriceRepository();
    when(
      () => bitcoinPriceRepository.getCurrencyValue(
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
      bitcoinPriceRepository: bitcoinPriceRepository,
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

  test(
    'opens one route when the key-server probe and Tor check run together',
    () async {
      final clock = _ManualTimers();
      final pool = TorRoutePool(timerFactory: clock.create);
      final events = <TorRoutePoolEvent>[];
      final routeOpen = Completer<TorRoute>();
      final probeStarted = Completer<void>();
      var closes = 0;
      final ensureTor = _MockEnsureTorReadyUsecase();

      final usecase = _usecase(
        settings: _settings(useTorProxy: false),
        ensureTor: ensureTor,
        routePool: pool,
        recoverBullHealthProbe: () async {
          final lease = pool.acquire(
            key: 'embedded',
            open: () async {
              probeStarted.complete();
              return routeOpen.future;
            },
            close: () async => closes++,
            onEvent: events.add,
          );
          await (await lease).release();
          return RecoverBullHealth.online;
        },
        recoverBullStatusProbe: (_) async => _backedUp,
      );

      final resultFuture = usecase.execute(network: Network.bitcoinMainnet);
      await probeStarted.future;
      routeOpen.complete(_route(TorSource.embedded));
      final result = await resultFuture;

      // The Tor row attached to the probe's route instead of opening its own.
      verifyNever(ensureTor.execute);
      expect(result.tor.status, ServiceStatus.online);
      expect(
        events.where((event) => event.type == TorRoutePoolEventType.opened),
        hasLength(1),
      );
      expect(closes, 0);
      clock.elapse();
      await Future<void>.delayed(Duration.zero);
      expect(closes, 1);
    },
  );

  test(
    'reports RecoverBull as unavailable when the feature did not start',
    () async {
      final usecase = _usecase(
        settings: _settings(useTorProxy: false),
        ensureTor: _unavailableEmbeddedTor(),
        recoverBull: RecoverBullFeature.unavailable(log: log.scoped('test')),
      );

      final result = await usecase.execute(network: Network.bitcoinMainnet);

      expect(result.recoverbull.status, ServiceStatus.unknown);
      expect(result.recoverbull.reason, ServiceStatusReason.featureUnavailable);
    },
  );

  test('promotes Tor to available when RecoverBull is online', () async {
    final usecase = _usecase(
      settings: _settings(useTorProxy: false),
      ensureTor: _unavailableEmbeddedTor(),
      recoverBullHealthProbe: () async => RecoverBullHealth.online,
      recoverBullStatusProbe: (_) async => _backedUp,
    );

    final result = await usecase.execute(network: Network.bitcoinMainnet);

    expect(result.tor.status, ServiceStatus.online);
    expect(result.tor.status, isNot(ServiceStatus.unknown));
  });

  test('does not promote Tor when RecoverBull fails or times out', () async {
    for (final health in [
      RecoverBullHealth.offline,
      RecoverBullHealth.timeout,
    ]) {
      final usecase = _usecase(
        settings: _settings(useTorProxy: false),
        ensureTor: _unavailableEmbeddedTor(),
        recoverBullHealthProbe: () async => health,
        recoverBullStatusProbe: (_) async => _backedUp,
      );

      final result = await usecase.execute(network: Network.bitcoinMainnet);

      expect(result.tor.status, ServiceStatus.offline);
      expect(result.recoverbull.status, ServiceStatus.offline);
    }
  });

  test('keeps the successful verdict over a concurrent failure', () async {
    final torFailure = Completer<TorConnectionState>();
    final recoverBullHealth = Completer<RecoverBullHealth>();
    final ensureTor = _MockEnsureTorReadyUsecase();
    when(() => ensureTor.execute()).thenAnswer((_) => torFailure.future);
    final usecase = _usecase(
      settings: _settings(useTorProxy: false),
      ensureTor: ensureTor,
      routePool: TorRoutePool(),
      recoverBullHealthProbe: () => recoverBullHealth.future,
      recoverBullStatusProbe: (_) async => _backedUp,
    );

    final resultFuture = usecase.execute(network: Network.bitcoinMainnet);
    torFailure.complete(
      const TorUnavailable(
        source: TorSource.embedded,
        failure: TorUnexpectedFailure('concurrent failure'),
      ),
    );
    recoverBullHealth.complete(RecoverBullHealth.online);
    final result = await resultFuture;

    expect(result.recoverbull.status, ServiceStatus.online);
    expect(result.tor.status, ServiceStatus.online);
  });

  test(
    'reports Tor offline when another caller never finishes opening the route',
    () async {
      // The Tor row attaches to the embedded route another caller is opening,
      // so it waits on that open, which may never complete.
      final pool = TorRoutePool();
      unawaited(
        pool.acquire(
          key: 'embedded',
          open: () => Completer<TorRoute>().future,
          close: () async {},
        ),
      );
      final ensureTor = _MockEnsureTorReadyUsecase();
      final usecase = _usecase(
        settings: _settings(useTorProxy: false),
        ensureTor: ensureTor,
        routePool: pool,
        recoverBullHealthProbe: () async => RecoverBullHealth.offline,
        recoverBullStatusProbe: (_) async => _backedUp,
        torStatusTimeout: const Duration(milliseconds: 50),
      );

      final result = await usecase.execute(network: Network.bitcoinMainnet);

      expect(result.tor.status, ServiceStatus.offline);
      verifyNever(ensureTor.execute);
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );

  test(
    'reports the external proxy offline when its route never finishes opening',
    () async {
      final pool = TorRoutePool();
      unawaited(
        pool.acquire(
          key: 'external:127.0.0.1:9050',
          open: () => Completer<TorRoute>().future,
          close: () async {},
        ),
      );
      final usecase = _usecase(
        settings: _settings(useTorProxy: true),
        routePool: pool,
        recoverBullStatusProbe: (_) async => const RecoverBullStatus.initial(),
        torStatusTimeout: const Duration(milliseconds: 50),
      );

      final result = await usecase.execute(network: Network.bitcoinMainnet);

      expect(result.tor.status, ServiceStatus.offline);
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );

  for (final (network, expected) in [
    (Network.bitcoinMainnet, RecoverBullNetwork.mainnet),
    (Network.bitcoinTestnet, RecoverBullNetwork.testnet),
  ]) {
    test('gates the key server on the ${expected.name} backup status when '
        'checking $network', () async {
      final asked = <RecoverBullNetwork>[];
      final usecase = _usecase(
        settings: _settings(useTorProxy: false),
        recoverBullHealthProbe: () async => RecoverBullHealth.online,
        recoverBullStatusProbe: (network) async {
          asked.add(network);
          return const RecoverBullStatus.initial();
        },
      );

      await usecase.execute(network: network);

      expect(asked, isNotEmpty);
      expect(asked.toSet(), {expected});
    });
  }

  for (final scenario in [
    ('no encrypted backup', const RecoverBullStatus.initial()),
    ('an unreadable backup status', const RecoverBullStatus.unavailable()),
  ]) {
    test('does not probe the key server with ${scenario.$1}', () async {
      // Without an encrypted backup the key server is unused: reaching it
      // would start Tor and contact the server for nothing.
      var probed = false;
      final usecase = _usecase(
        settings: _settings(useTorProxy: false),
        recoverBullHealthProbe: () async {
          probed = true;
          return RecoverBullHealth.online;
        },
        recoverBullStatusProbe: (_) async => scenario.$2,
      );

      final result = await usecase.execute(network: Network.bitcoinMainnet);

      expect(probed, isFalse);
      expect(result.recoverbull.status, ServiceStatus.unknown);
      expect(result.tor.status, ServiceStatus.unknown);
    });
  }
}

final _backedUp = RecoverBullStatus(lastEncryptedBackupAt: DateTime(2026));

_MockEnsureTorReadyUsecase _unavailableEmbeddedTor() {
  final ensureTor = _MockEnsureTorReadyUsecase();
  when(ensureTor.execute).thenAnswer(
    (_) => Future<TorConnectionState>.value(
      const TorUnavailable(
        source: TorSource.embedded,
        failure: TorUnexpectedFailure('embedded Tor down'),
      ),
    ),
  );
  return ensureTor;
}

CheckAllServiceStatusUsecase _usecase({
  required SettingsEntity settings,
  _MockTor? tor,
  _MockEnsureTorReadyUsecase? ensureTor,
  TorRoutePool? routePool,
  Future<RecoverBullHealth> Function()? recoverBullHealthProbe,
  Future<RecoverBullStatus> Function(RecoverBullNetwork)?
  recoverBullStatusProbe,
  RecoverBullFeature? recoverBull,
  Duration torStatusTimeout =
      CheckAllServiceStatusUsecase.defaultTorStatusTimeout,
}) {
  final electrum = _MockElectrumConnectivityPort();
  when(
    () => electrum.checkServersInUseAreOnlineForNetwork(any()),
  ).thenAnswer((_) async => true);
  final bitcoinPriceRepository = _MockBitcoinPriceRepository();
  when(
    () => bitcoinPriceRepository.getCurrencyValue(
      amountSat: any(named: 'amountSat'),
      currency: any(named: 'currency'),
    ),
  ).thenAnswer((_) async => 1);
  final fees = _MockFeesRepository();
  when(
    () => fees.getNetworkFees(network: any(named: 'network')),
  ).thenAnswer((_) async => throw Exception('Mempool probe disabled'));
  final payjoinPolicy = _MockPayjoinPolicyAccess();
  when(
    payjoinPolicy.load,
  ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
  final settingsRepository = _MockSettingsRepository();
  when(settingsRepository.fetch).thenAnswer((_) async => settings);

  return CheckAllServiceStatusUsecase(
    electrumConnectivityPort: electrum,
    bitcoinPriceRepository: bitcoinPriceRepository,
    payjoinPolicy: payjoinPolicy,
    payjoinDiagnostics: _MockPayjoinDiagnostics(),
    feesRepository: fees,
    ensureTorReadyUsecase: ensureTor ?? _MockEnsureTorReadyUsecase(),
    settingsRepository: settingsRepository,
    tor: tor ?? _MockTor(),
    recoverBull: recoverBull,
    routePool: routePool,
    recoverBullHealthProbe: recoverBullHealthProbe,
    recoverBullStatusProbe: recoverBullStatusProbe,
    torStatusTimeout: torStatusTimeout,
  );
}

final class _ManualTimers {
  final List<_ManualTimer> _timers = [];

  TorRoutePoolTimer create(Duration _, void Function() callback) {
    final timer = _ManualTimer(callback);
    _timers.add(timer);
    return timer;
  }

  void elapse() {
    for (final timer in List<_ManualTimer>.from(_timers)) {
      timer.fire();
    }
  }
}

final class _ManualTimer implements TorRoutePoolTimer {
  final void Function() _callback;
  bool cancelled = false;

  _ManualTimer(this._callback);

  @override
  void cancel() => cancelled = true;

  void fire() {
    if (cancelled) return;
    cancelled = true;
    _callback();
  }
}
