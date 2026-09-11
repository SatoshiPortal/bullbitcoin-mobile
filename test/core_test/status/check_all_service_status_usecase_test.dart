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
import 'package:bull_recoverbull/bull_recoverbull.dart';
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

  test(
    'opens one route during a complete check with both probes active',
    () async {
      final clock = _ManualTimers();
      final pool = TorRoutePool(timerFactory: clock.create);
      final events = <TorRoutePoolEvent>[];
      final callsStarted = Completer<void>();
      final leasesAcquired = Completer<void>();
      final routeOpen = Completer<TorRoute>();
      var probeCalls = 0;
      var leaseCount = 0;
      var closes = 0;
      Future<TorRouteLease> acquireProbe() async {
        probeCalls++;
        if (probeCalls == 2) callsStarted.complete();
        final lease = await pool.acquire(
          key: 'embedded',
          open: () async {
            await callsStarted.future;
            return routeOpen.future;
          },
          close: () async => closes++,
          onEvent: events.add,
        );
        leaseCount++;
        if (leaseCount == 2) leasesAcquired.complete();
        return lease;
      }

      final usecase = _usecase(
        settings: _settings(useTorProxy: false),
        routePool: pool,
        recoverBullHealthProbe: () async {
          final lease = await acquireProbe();
          await leasesAcquired.future;
          await lease.release();
          return RecoverBullHealth.online;
        },
        recoverBullStatusProbe: () async {
          final lease = await acquireProbe();
          await leasesAcquired.future;
          await lease.release();
          return const RecoverBullStatus.unavailable();
        },
      );

      final resultFuture = usecase.execute(network: Network.bitcoinMainnet);
      await callsStarted.future;
      routeOpen.complete(_route(TorSource.embedded));
      await resultFuture;

      expect(
        events.where((event) => event.type == TorRoutePoolEventType.opened),
        hasLength(1),
      );
      expect(
        events.where((event) => event.type == TorRoutePoolEventType.attached),
        hasLength(1),
      );
      expect(events.map((event) => event.holders), containsAll([1, 2]));
      expect(closes, 0);
      clock.elapse();
      await Future<void>.delayed(Duration.zero);
      expect(closes, 1);
    },
  );

  test('promotes Tor to available when RecoverBull is online', () async {
    final usecase = _usecase(
      settings: _settings(useTorProxy: false),
      recoverBullHealthProbe: () async => RecoverBullHealth.online,
      recoverBullStatusProbe: () async => const RecoverBullStatus.unavailable(),
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
        recoverBullHealthProbe: () async => health,
        recoverBullStatusProbe: () async =>
            const RecoverBullStatus.unavailable(),
      );

      final result = await usecase.execute(network: Network.bitcoinMainnet);

      expect(result.tor.status, ServiceStatus.unknown);
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
      recoverBullStatusProbe: () async => const RecoverBullStatus.initial(),
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
}

CheckAllServiceStatusUsecase _usecase({
  required SettingsEntity settings,
  _MockTor? tor,
  _MockEnsureTorReadyUsecase? ensureTor,
  TorRoutePool? routePool,
  Future<RecoverBullHealth> Function()? recoverBullHealthProbe,
  Future<RecoverBullStatus> Function()? recoverBullStatusProbe,
}) {
  final electrum = _MockElectrumConnectivityPort();
  when(
    () => electrum.checkServersInUseAreOnlineForNetwork(any()),
  ).thenAnswer((_) async => true);
  final exchangeRate = _MockExchangeRateRepository();
  when(
    () => exchangeRate.getCurrencyValue(
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
    exchangeRateRepository: exchangeRate,
    payjoinPolicy: payjoinPolicy,
    payjoinDiagnostics: _MockPayjoinDiagnostics(),
    feesRepository: fees,
    ensureTorReadyUsecase: ensureTor ?? _MockEnsureTorReadyUsecase(),
    settingsRepository: settingsRepository,
    tor: tor ?? _MockTor(),
    routePool: routePool,
    recoverBullHealthProbe: recoverBullHealthProbe,
    recoverBullStatusProbe: recoverBullStatusProbe,
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
