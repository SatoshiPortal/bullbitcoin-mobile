import 'package:electrum/electrum.dart';
import 'package:network/src/tor_settings/domain/tor_preferences.dart';

import 'dart:async';

import 'package:network/src/status_check/domain/service_status.dart';
import 'package:network/src/status_check/domain/check_all_service_status_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_tor/tor.dart';
import 'package:clock/clock.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, NetworkEnv, Result, Err, Ok;

class _MockElectrumServers extends Mock implements ElectrumServers {}

class _MockPayjoinPolicyAccess extends Mock implements PayjoinPolicyAccess {}

class _MockPayjoinDiagnostics extends Mock implements PayjoinDiagnostics {}

class _MockFeesRepository extends Mock implements _BitcoinFees {}

class _MockWalletRepository extends Mock implements _WalletUsage {}

class _MockSettingsRepository extends Mock implements _SettingsAccess {}

abstract interface class _SettingsAccess {
  Future<TorPreferences> fetch();
}

abstract interface class _WalletUsage {
  Future<bool> isTorRequired();
}

abstract interface class _BitcoinFees {
  Future<void> getNetworkFees({required BitcoinNetwork network});
}

class _MockTor extends Mock implements Tor {}

class _MockExternalTor extends Mock implements ExternalTor {}

TorPreferences _settings({required bool useTorProxy, int port = 9050}) => (
  useTorProxy: useTorProxy,
  torProxyPort: port,
  torTransportMode: TorTransportMode.automatic,
  lastSuccessfulTorTransport: null,
);

void main() {
  setUpAll(() {
    registerFallbackValue(TorProxyEndpoint(host: '127.0.0.1', port: 9050));
    registerFallbackValue(ElectrumServerNetwork.bitcoinMainnet);
    registerFallbackValue(BitcoinNetwork.mainnet);
    registerFallbackValue(BigInt.zero);
  });
  // The price repository answers from a price up to a minute old without
  // asking the pricer: the status must say when the pricer last answered.
  test('the pricer is dated by its last real answer, not by now', () async {
    final fetchedAt = DateTime.utc(2026, 10, 21, 12);
    final electrum = _MockElectrumServers();
    when(() => electrum.check(network: any(named: 'network')))
        .thenAnswer((_) async => const Ok(ElectrumServerStatus.online));
    final getIndexPrice = _FakeIndexPriceReader(fiatAmount: 70000)
      ..fetchedAt = fetchedAt;
    final feesRepository = _MockFeesRepository();
    when(() => feesRepository.getNetworkFees(network: any(named: 'network')))
        .thenAnswer((_) async => throw Exception('Mempool probe failed'));
    final payjoinPolicy = _MockPayjoinPolicyAccess();
    final walletRepository = _MockWalletRepository();
    when(walletRepository.isTorRequired).thenAnswer((_) async => false);
    when(payjoinPolicy.load).thenAnswer((_) async => Ok(_allPayjoinOff()));
    final settingsRepository = _MockSettingsRepository();
    final tor = _MockTor();
    when(() => settingsRepository.fetch())
        .thenAnswer((_) async => _settings(useTorProxy: false));
    when(() => tor.external).thenReturn(_MockExternalTor());
    final usecase = CheckAllServiceStatusUsecase(
      electrumServers: electrum,
      getIndexPrice: getIndexPrice.call,
      payjoinPolicy: payjoinPolicy,
      payjoinDiagnostics: _MockPayjoinDiagnostics(),
      checkBitcoinFees: (network) =>
          feesRepository.getNetworkFees(network: network),
      isTorRequired: walletRepository.isTorRequired,

      checkServerConnection: () async => const Ok(false),
      readTorPreferences: settingsRepository.fetch,
      tor: tor,
    );

    final status = await usecase.execute(network: NetworkEnv.mainnet);

    expect(status.pricer.status, ServiceStatus.online);
    expect(status.pricer.lastChecked, fetchedAt.toLocal());
    expect(getIndexPrice.requests.single, (
      network: BitcoinNetwork.mainnet,
      currency: SupportedCurrency.usd,
    ));
  });

  test('an offline pricer is dated by the controlled clock', () async {
    final now = DateTime(2026, 10, 21, 12, 30);
    final electrum = _MockElectrumServers();
    when(() => electrum.check(network: any(named: 'network')))
        .thenAnswer((_) async => const Ok(ElectrumServerStatus.online));
    final getIndexPrice = _FakeIndexPriceReader(
      failure: const PricerNetworkFailure('offline'),
    );
    final feesRepository = _MockFeesRepository();
    when(() => feesRepository.getNetworkFees(network: any(named: 'network')))
        .thenAnswer((_) async => throw Exception('Mempool probe failed'));
    final payjoinPolicy = _MockPayjoinPolicyAccess();
    final walletRepository = _MockWalletRepository();
    when(walletRepository.isTorRequired).thenAnswer((_) async => false);
    when(payjoinPolicy.load).thenAnswer((_) async => Ok(_allPayjoinOff()));
    final settingsRepository = _MockSettingsRepository();
    final tor = _MockTor();
    when(() => settingsRepository.fetch())
        .thenAnswer((_) async => _settings(useTorProxy: false));
    when(() => tor.external).thenReturn(_MockExternalTor());
    final usecase = CheckAllServiceStatusUsecase(
      electrumServers: electrum,
      getIndexPrice: getIndexPrice.call,
      payjoinPolicy: payjoinPolicy,
      payjoinDiagnostics: _MockPayjoinDiagnostics(),
      checkBitcoinFees: (network) =>
          feesRepository.getNetworkFees(network: network),
      isTorRequired: walletRepository.isTorRequired,

      checkServerConnection: () async => const Ok(false),
      readTorPreferences: settingsRepository.fetch,
      tor: tor,
    );

    final status = await withClock(
      Clock.fixed(now),
      () => usecase.execute(network: NetworkEnv.mainnet),
    );

    expect(status.pricer.status, ServiceStatus.offline);
    expect(status.pricer.lastChecked, now);
  });

  test(
    'Payjoin with every switch off is not probed or reported offline',
    () async {
      final electrum = _MockElectrumServers();
      when(() => electrum.check(network: any(named: 'network')))
          .thenAnswer((_) async => const Ok(ElectrumServerStatus.online));
      final getIndexPrice = _FakeIndexPriceReader(
        failure: const PricerNetworkFailure('Pricer probe failed'),
      );
      final feesRepository = _MockFeesRepository();
      when(() => feesRepository.getNetworkFees(network: any(named: 'network')))
          .thenAnswer((_) async => throw Exception('Mempool probe failed'));
      final payjoinPolicy = _MockPayjoinPolicyAccess();
      final payjoinDiagnostics = _MockPayjoinDiagnostics();
      final walletRepository = _MockWalletRepository();
      // Tor is not required for this wallet, so neither the Tor nor the
      // RecoverBull probe is reached — the point of the test is Payjoin.
      when(walletRepository.isTorRequired).thenAnswer((_) async => false);
      when(payjoinPolicy.load).thenAnswer((_) async => Ok(_allPayjoinOff()));
      final settingsRepository = _MockSettingsRepository();
      final tor = _MockTor();
      final external = _MockExternalTor();
      when(() => settingsRepository.fetch())
          .thenAnswer((_) async => _settings(useTorProxy: false));
      when(() => tor.external).thenReturn(external);
      final usecase = CheckAllServiceStatusUsecase(
        electrumServers: electrum,
        getIndexPrice: getIndexPrice.call,
        payjoinPolicy: payjoinPolicy,
        payjoinDiagnostics: payjoinDiagnostics,
        checkBitcoinFees: (network) =>
            feesRepository.getNetworkFees(network: network),
        isTorRequired: walletRepository.isTorRequired,

        checkServerConnection: () async => const Ok(false),
        readTorPreferences: settingsRepository.fetch,
        tor: tor,
      );

      final status = await usecase.execute(network: NetworkEnv.mainnet);

      expect(status.payjoin.status, ServiceStatus.disabled);
      expect(status.payjoin.isOffline, isFalse);
      verifyNever(payjoinDiagnostics.relayHealth);
    },
  );

  test(
    'reports configured external Tor ready without a backup wallet',
    () async {
      final walletRepository = _MockWalletRepository();
      when(walletRepository.isTorRequired).thenAnswer((_) async => false);
      final electrum = _MockElectrumServers();
      when(() => electrum.check(network: any(named: 'network')))
          .thenAnswer((_) async => const Ok(ElectrumServerStatus.online));
      final getIndexPrice = _FakeIndexPriceReader(
        failure: const PricerNetworkFailure('Pricer probe failed'),
      );
      final feesRepository = _MockFeesRepository();
      when(() => feesRepository.getNetworkFees(network: any(named: 'network')))
          .thenAnswer((_) async => throw Exception('Mempool probe failed'));
      final payjoinPolicy = _MockPayjoinPolicyAccess();
      when(payjoinPolicy.load).thenAnswer((_) async => Ok(_allPayjoinOff()));
      final settingsRepository = _MockSettingsRepository();
      final tor = _MockTor();
      final external = _MockExternalTor();
      when(() => settingsRepository.fetch())
          .thenAnswer((_) async => _settings(useTorProxy: true));
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
        electrumServers: electrum,
        getIndexPrice: getIndexPrice.call,
        payjoinPolicy: payjoinPolicy,
        payjoinDiagnostics: _MockPayjoinDiagnostics(),
        checkBitcoinFees: (network) =>
            feesRepository.getNetworkFees(network: network),
        isTorRequired: walletRepository.isTorRequired,

        checkServerConnection: () async => const Ok(false),
        readTorPreferences: settingsRepository.fetch,
        tor: tor,
      );

      final status = await usecase.execute(network: NetworkEnv.mainnet);

      expect(status.tor.status, ServiceStatus.online);
      verifyNever(walletRepository.isTorRequired);
    },
  );

  test(
    'reports configured external Tor unavailable without a backup wallet',
    () async {
      final walletRepository = _MockWalletRepository();
      when(walletRepository.isTorRequired).thenAnswer((_) async => false);
      final electrum = _MockElectrumServers();
      when(() => electrum.check(network: any(named: 'network')))
          .thenAnswer((_) async => const Ok(ElectrumServerStatus.online));
      final getIndexPrice = _FakeIndexPriceReader(
        failure: const PricerNetworkFailure('Pricer probe failed'),
      );
      final feesRepository = _MockFeesRepository();
      when(() => feesRepository.getNetworkFees(network: any(named: 'network')))
          .thenAnswer((_) async => throw Exception('Mempool probe failed'));
      final payjoinPolicy = _MockPayjoinPolicyAccess();
      when(payjoinPolicy.load).thenAnswer((_) async => Ok(_allPayjoinOff()));
      final settingsRepository = _MockSettingsRepository();
      final tor = _MockTor();
      final external = _MockExternalTor();
      when(() => settingsRepository.fetch())
          .thenAnswer((_) async => _settings(useTorProxy: true));
      when(() => tor.external).thenReturn(external);
      when(() => external.verify(any())).thenAnswer(
        (_) async => const TorUnavailable(
          source: TorSource.external,
          failure: TorExternalProxyUnavailableFailure(),
        ),
      );
      final usecase = CheckAllServiceStatusUsecase(
        electrumServers: electrum,
        getIndexPrice: getIndexPrice.call,
        payjoinPolicy: payjoinPolicy,
        payjoinDiagnostics: _MockPayjoinDiagnostics(),
        checkBitcoinFees: (network) =>
            feesRepository.getNetworkFees(network: network),
        isTorRequired: walletRepository.isTorRequired,

        checkServerConnection: () async => const Ok(false),
        readTorPreferences: settingsRepository.fetch,
        tor: tor,
      );

      final status = await usecase.execute(network: NetworkEnv.mainnet);

      expect(status.tor.status, ServiceStatus.offline);
      verifyNever(walletRepository.isTorRequired);
    },
  );

  test(
    'publishes completed services while Bitcoin Electrum is pending',
    () async {
      final electrum = _MockElectrumServers();
      final bitcoinResult =
          Completer<Result<ElectrumServerStatus, ElectrumFailure>>();
      when(() => electrum.check(network: ElectrumServerNetwork.bitcoinMainnet))
          .thenAnswer((_) => bitcoinResult.future);
      when(() => electrum.check(network: ElectrumServerNetwork.liquidMainnet))
          .thenAnswer((_) async => const Ok(ElectrumServerStatus.online));
      final getIndexPrice = _FakeIndexPriceReader(
        failure: const PricerNetworkFailure('Pricer probe failed'),
      );
      final feesRepository = _MockFeesRepository();
      when(() => feesRepository.getNetworkFees(network: any(named: 'network')))
          .thenAnswer((_) async => throw Exception('Mempool probe failed'));

      final walletRepository = _MockWalletRepository();
      when(walletRepository.isTorRequired).thenAnswer((_) async => false);
      final settingsRepository = _MockSettingsRepository();
      when(() => settingsRepository.fetch())
          .thenAnswer((_) async => _settings(useTorProxy: false));
      final payjoinPolicy = _MockPayjoinPolicyAccess();
      when(payjoinPolicy.load).thenAnswer((_) async => Ok(_allPayjoinOff()));

      final usecase = CheckAllServiceStatusUsecase(
        electrumServers: electrum,
        getIndexPrice: getIndexPrice.call,
        payjoinPolicy: payjoinPolicy,
        payjoinDiagnostics: _MockPayjoinDiagnostics(),
        checkBitcoinFees: (network) =>
            feesRepository.getNetworkFees(network: network),
        isTorRequired: walletRepository.isTorRequired,

        checkServerConnection: () async => const Ok(false),
        readTorPreferences: settingsRepository.fetch,
        tor: _MockTor(),
      );
      final liquidPublished = Completer<void>();
      var completed = false;

      final resultFuture = usecase.execute(
        network: NetworkEnv.mainnet,
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
      bitcoinResult.complete(const Ok(ElectrumServerStatus.online));

      final result = await resultFuture;
      expect(result.bitcoinElectrum.isOnline, isTrue);
      expect(result.liquidElectrum.isOnline, isTrue);
      expect(result.lastChecked, isNotNull);
    },
  );

  test('keeps completed service results when another task throws', () async {
    final electrum = _MockElectrumServers();
    when(() => electrum.check(network: ElectrumServerNetwork.bitcoinMainnet))
        .thenAnswer((_) async => const Err(ElectrumLoadFailure()));
    when(() => electrum.check(network: ElectrumServerNetwork.liquidMainnet))
        .thenAnswer((_) async => const Ok(ElectrumServerStatus.online));
    final getIndexPrice = _FakeIndexPriceReader(
      failure: const PricerNetworkFailure('Pricer probe failed'),
    );
    final feesRepository = _MockFeesRepository();
    when(() => feesRepository.getNetworkFees(network: any(named: 'network')))
        .thenAnswer((_) async => throw Exception('Mempool probe failed'));

    final walletRepository = _MockWalletRepository();
    when(walletRepository.isTorRequired).thenAnswer((_) async => false);
    final settingsRepository = _MockSettingsRepository();
    when(settingsRepository.fetch).thenThrow(Exception('Tor probe failed'));
    final payjoinPolicy = _MockPayjoinPolicyAccess();
    when(payjoinPolicy.load).thenAnswer((_) async => Ok(_allPayjoinOff()));

    final updates = <AllServicesStatus>[];
    final usecase = CheckAllServiceStatusUsecase(
      electrumServers: electrum,
      getIndexPrice: getIndexPrice.call,
      payjoinPolicy: payjoinPolicy,
      payjoinDiagnostics: _MockPayjoinDiagnostics(),
      checkBitcoinFees: (network) =>
          feesRepository.getNetworkFees(network: network),
      isTorRequired: walletRepository.isTorRequired,

      checkServerConnection: () async => const Ok(false),
      readTorPreferences: settingsRepository.fetch,
      tor: _MockTor(),
    );

    final result = await usecase.execute(
      network: NetworkEnv.mainnet,
      onUpdate: updates.add,
    );

    expect(updates.any((status) => status.liquidElectrum.isOnline), isTrue);
    expect(result.bitcoinElectrum.status, ServiceStatus.offline);
    expect(result.liquidElectrum.isOnline, isTrue);
    expect(result.lastChecked, isNotNull);
  });

  test('reports only the failing Electrum probe as unknown when it throws an Exception', () async {
    final electrum = _MockElectrumServers();
    when(() => electrum.check(network: ElectrumServerNetwork.bitcoinMainnet))
        .thenAnswer((_) async => const Ok(ElectrumServerStatus.online));
    when(() => electrum.check(network: ElectrumServerNetwork.liquidMainnet))
        .thenAnswer((_) async => throw Exception('Electrum probe failed'));
    final getIndexPrice = _FakeIndexPriceReader(
      failure: const PricerNetworkFailure('Pricer probe failed'),
    );
    final feesRepository = _MockFeesRepository();
    when(() => feesRepository.getNetworkFees(network: any(named: 'network')))
        .thenAnswer((_) async => throw Exception('Mempool probe failed'));
    final payjoinPolicy = _MockPayjoinPolicyAccess();
    when(payjoinPolicy.load).thenAnswer((_) async => Ok(_allPayjoinOff()));
    final walletRepository = _MockWalletRepository();
    when(walletRepository.isTorRequired).thenAnswer((_) async => false);
    final settingsRepository = _MockSettingsRepository();
    when(() => settingsRepository.fetch())
        .thenAnswer((_) async => _settings(useTorProxy: false));

    final usecase = CheckAllServiceStatusUsecase(
      electrumServers: electrum,
      getIndexPrice: getIndexPrice.call,
      payjoinPolicy: payjoinPolicy,
      payjoinDiagnostics: _MockPayjoinDiagnostics(),
      checkBitcoinFees: (network) =>
          feesRepository.getNetworkFees(network: network),
      isTorRequired: walletRepository.isTorRequired,

      checkServerConnection: () async => const Ok(false),
      readTorPreferences: settingsRepository.fetch,
      tor: _MockTor(),
    );

    final result = await usecase.execute(network: NetworkEnv.mainnet);

    expect(result.bitcoinElectrum.status, ServiceStatus.online);
    expect(result.liquidElectrum.status, ServiceStatus.unknown);
  });

  test('propagates a StateError from a service probe', () async {
    final electrum = _MockElectrumServers();
    when(() => electrum.check(network: ElectrumServerNetwork.bitcoinMainnet))
        .thenAnswer((_) async => throw StateError('Electrum probe failed'));
    final getIndexPrice = _FakeIndexPriceReader(
      failure: const PricerNetworkFailure('Pricer probe failed'),
    );
    final feesRepository = _MockFeesRepository();
    when(() => feesRepository.getNetworkFees(network: any(named: 'network')))
        .thenAnswer((_) async => throw Exception('Mempool probe failed'));
    final payjoinPolicy = _MockPayjoinPolicyAccess();
    when(payjoinPolicy.load).thenAnswer((_) async => Ok(_allPayjoinOff()));
    final walletRepository = _MockWalletRepository();
    when(walletRepository.isTorRequired).thenAnswer((_) async => false);
    final settingsRepository = _MockSettingsRepository();
    when(() => settingsRepository.fetch())
        .thenAnswer((_) async => _settings(useTorProxy: false));

    final usecase = CheckAllServiceStatusUsecase(
      electrumServers: electrum,
      getIndexPrice: getIndexPrice.call,
      payjoinPolicy: payjoinPolicy,
      payjoinDiagnostics: _MockPayjoinDiagnostics(),
      checkBitcoinFees: (network) =>
          feesRepository.getNetworkFees(network: network),
      isTorRequired: walletRepository.isTorRequired,

      checkServerConnection: () async => const Ok(false),
      readTorPreferences: settingsRepository.fetch,
      tor: _MockTor(),
    );

    await expectLater(
      usecase.execute(network: NetworkEnv.mainnet),
      throwsA(isA<StateError>()),
    );
  });
}

/// Send and the exchange switches ship on, so payjoin is unused only with all
/// four off.
PayjoinPolicy _allPayjoinOff() => PayjoinPolicy.defaults()
    .withAction(PayjoinAction.send, enabled: false)
    .withAction(PayjoinAction.buy, enabled: false)
    .withAction(PayjoinAction.sell, enabled: false);

/// Stands in for `Pricer.getIndexPrice`: answers [fiatAmount] in the
/// requested currency, or [failure] when set, and records each request.
class _FakeIndexPriceReader {
  double fiatAmount;
  PricerFailure? failure;
  DateTime fetchedAt = DateTime.utc(2026, 11, 4, 12);
  final List<({BitcoinNetwork network, SupportedCurrency currency})> requests =
      [];

  _FakeIndexPriceReader({this.fiatAmount = 100000, this.failure});

  Future<Result<BitcoinPrice, PricerFailure>> call({
    required BitcoinNetwork network,
    required SupportedCurrency currency,
  }) async {
    requests.add((network: network, currency: currency));
    final failure = this.failure;
    if (failure != null) return Err(failure);
    return Ok(
      BitcoinPrice(
        currency: currency,
        fiatAmount: fiatAmount,
        fetchedAt: fetchedAt,
      ),
    );
  }
}
