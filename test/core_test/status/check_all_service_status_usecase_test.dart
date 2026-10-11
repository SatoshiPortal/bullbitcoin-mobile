import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/status/domain/entity/service_status.dart';
import 'package:bb_mobile/core/status/domain/ports/electrum_connectivity_port.dart';
import 'package:bb_mobile/features/status_check/domain/check_all_service_status_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_tor/tor.dart';
import 'package:clock/clock.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, BitcoinUnit, Ok;

import '../../fake_index_price_reader.dart';

class _MockElectrumConnectivityPort extends Mock
    implements ElectrumConnectivityPort {}

class _MockPayjoinPolicyAccess extends Mock implements PayjoinPolicyAccess {}

class _MockPayjoinDiagnostics extends Mock implements PayjoinDiagnostics {}

class _MockFeesRepository extends Mock implements FeesRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

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

class _ProbeClient extends Mock implements HttpClient {}

class _ProbeRequest extends Mock implements HttpClientRequest {}

class _ProbeHeaders extends Mock implements HttpHeaders {}

class _ProbeResponse extends Mock implements HttpClientResponse {
  final Stream<List<int>> _body;
  _ProbeResponse(this._body);
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _body.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}

CheckAllServiceStatusUsecase _backupProbeUsecase() {
  final electrum = _MockElectrumConnectivityPort();
  when(
    () => electrum.checkServersInUseAreOnlineForNetwork(any()),
  ).thenAnswer((_) async => true);
  final rates = FakeIndexPriceReader(fiatAmount: 100);
  final fees = _MockFeesRepository();
  when(
    () => fees.getNetworkFees(network: any(named: 'network')),
  ).thenAnswer((_) async => throw Exception('unrelated fee probe'));
  final policy = _MockPayjoinPolicyAccess();
  when(policy.load).thenAnswer((_) async => Ok(_allPayjoinOff()));
  final wallets = _MockWalletRepository();
  when(wallets.isTorRequired).thenAnswer((_) async => false);
  final settings = _MockSettingsRepository();
  when(settings.fetch).thenAnswer((_) async => _settings(useTorProxy: false));
  return CheckAllServiceStatusUsecase(
    electrumConnectivityPort: electrum,
    getIndexPrice: rates.call,
    payjoinPolicy: policy,
    payjoinDiagnostics: _MockPayjoinDiagnostics(),
    feesRepository: fees,
    walletRepository: wallets,
    ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
    checkServerConnection: () async => const Ok(true),
    settingsRepository: settings,
    tor: _MockTor(),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(TorProxyEndpoint(host: '127.0.0.1', port: 9050));
    registerFallbackValue(Network.bitcoinMainnet);
    registerFallbackValue(BigInt.zero);
  });
  // The price repository answers from a price up to a minute old without
  // asking the pricer: the status must say when the pricer last answered.
  test('the pricer is dated by its last real answer, not by now', () async {
    final fetchedAt = DateTime.utc(2026, 10, 21, 12);
    final electrum = _MockElectrumConnectivityPort();
    when(
      () => electrum.checkServersInUseAreOnlineForNetwork(any()),
    ).thenAnswer((_) async => true);
    final getIndexPrice = FakeIndexPriceReader(fiatAmount: 70000)
      ..fetchedAt = fetchedAt;
    final feesRepository = _MockFeesRepository();
    when(
      () => feesRepository.getNetworkFees(network: any(named: 'network')),
    ).thenAnswer((_) async => throw Exception('Mempool probe failed'));
    final payjoinPolicy = _MockPayjoinPolicyAccess();
    final walletRepository = _MockWalletRepository();
    when(walletRepository.isTorRequired).thenAnswer((_) async => false);
    when(payjoinPolicy.load).thenAnswer((_) async => Ok(_allPayjoinOff()));
    final settingsRepository = _MockSettingsRepository();
    final tor = _MockTor();
    when(
      () => settingsRepository.fetch(),
    ).thenAnswer((_) async => _settings(useTorProxy: false));
    when(() => tor.external).thenReturn(_MockExternalTor());
    final usecase = CheckAllServiceStatusUsecase(
      electrumConnectivityPort: electrum,
      getIndexPrice: getIndexPrice.call,
      payjoinPolicy: payjoinPolicy,
      payjoinDiagnostics: _MockPayjoinDiagnostics(),
      feesRepository: feesRepository,
      walletRepository: walletRepository,
      ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
      checkServerConnection: () async => const Ok(false),
      settingsRepository: settingsRepository,
      tor: tor,
    );

    final status = await usecase.execute(network: Network.bitcoinMainnet);

    expect(status.pricer.status, ServiceStatus.online);
    expect(status.pricer.lastChecked, fetchedAt.toLocal());
    expect(getIndexPrice.requests.single, (
      network: BitcoinNetwork.mainnet,
      currency: SupportedCurrency.usd,
    ));
  });

  test('an offline pricer is dated by the controlled clock', () async {
    final now = DateTime(2026, 10, 21, 12, 30);
    final electrum = _MockElectrumConnectivityPort();
    when(
      () => electrum.checkServersInUseAreOnlineForNetwork(any()),
    ).thenAnswer((_) async => true);
    final getIndexPrice = FakeIndexPriceReader(
      failure: const PricerNetworkFailure('offline'),
    );
    final feesRepository = _MockFeesRepository();
    when(
      () => feesRepository.getNetworkFees(network: any(named: 'network')),
    ).thenAnswer((_) async => throw Exception('Mempool probe failed'));
    final payjoinPolicy = _MockPayjoinPolicyAccess();
    final walletRepository = _MockWalletRepository();
    when(walletRepository.isTorRequired).thenAnswer((_) async => false);
    when(payjoinPolicy.load).thenAnswer((_) async => Ok(_allPayjoinOff()));
    final settingsRepository = _MockSettingsRepository();
    final tor = _MockTor();
    when(
      () => settingsRepository.fetch(),
    ).thenAnswer((_) async => _settings(useTorProxy: false));
    when(() => tor.external).thenReturn(_MockExternalTor());
    final usecase = CheckAllServiceStatusUsecase(
      electrumConnectivityPort: electrum,
      getIndexPrice: getIndexPrice.call,
      payjoinPolicy: payjoinPolicy,
      payjoinDiagnostics: _MockPayjoinDiagnostics(),
      feesRepository: feesRepository,
      walletRepository: walletRepository,
      ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
      checkServerConnection: () async => const Ok(false),
      settingsRepository: settingsRepository,
      tor: tor,
    );

    final status = await withClock(
      Clock.fixed(now),
      () => usecase.execute(network: Network.bitcoinMainnet),
    );

    expect(status.pricer.status, ServiceStatus.offline);
    expect(status.pricer.lastChecked, now);
  });

  test(
    'Payjoin with every switch off is not probed or reported offline',
    () async {
      final electrum = _MockElectrumConnectivityPort();
      when(
        () => electrum.checkServersInUseAreOnlineForNetwork(any()),
      ).thenAnswer((_) async => true);
      final getIndexPrice = FakeIndexPriceReader(
        failure: const PricerNetworkFailure('Pricer probe failed'),
      );
      final feesRepository = _MockFeesRepository();
      when(
        () => feesRepository.getNetworkFees(network: any(named: 'network')),
      ).thenAnswer((_) async => throw Exception('Mempool probe failed'));
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
      when(
        () => settingsRepository.fetch(),
      ).thenAnswer((_) async => _settings(useTorProxy: false));
      when(() => tor.external).thenReturn(external);
      final usecase = CheckAllServiceStatusUsecase(
        electrumConnectivityPort: electrum,
        getIndexPrice: getIndexPrice.call,
        payjoinPolicy: payjoinPolicy,
        payjoinDiagnostics: payjoinDiagnostics,
        feesRepository: feesRepository,
        walletRepository: walletRepository,
        ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
        checkServerConnection: () async => const Ok(false),
        settingsRepository: settingsRepository,
        tor: tor,
      );

      final status = await usecase.execute(network: Network.bitcoinMainnet);

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
      final electrum = _MockElectrumConnectivityPort();
      when(
        () => electrum.checkServersInUseAreOnlineForNetwork(any()),
      ).thenAnswer((_) async => true);
      final getIndexPrice = FakeIndexPriceReader(
        failure: const PricerNetworkFailure('Pricer probe failed'),
      );
      final feesRepository = _MockFeesRepository();
      when(
        () => feesRepository.getNetworkFees(network: any(named: 'network')),
      ).thenAnswer((_) async => throw Exception('Mempool probe failed'));
      final payjoinPolicy = _MockPayjoinPolicyAccess();
      when(payjoinPolicy.load).thenAnswer((_) async => Ok(_allPayjoinOff()));
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
        getIndexPrice: getIndexPrice.call,
        payjoinPolicy: payjoinPolicy,
        payjoinDiagnostics: _MockPayjoinDiagnostics(),
        feesRepository: feesRepository,
        walletRepository: walletRepository,
        ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
        checkServerConnection: () async => const Ok(false),
        settingsRepository: settingsRepository,
        tor: tor,
      );

      final status = await usecase.execute(network: Network.bitcoinMainnet);

      expect(status.tor.status, ServiceStatus.online);
      verifyNever(walletRepository.isTorRequired);
    },
  );

  test(
    'reports configured external Tor unavailable without a backup wallet',
    () async {
      final walletRepository = _MockWalletRepository();
      when(walletRepository.isTorRequired).thenAnswer((_) async => false);
      final electrum = _MockElectrumConnectivityPort();
      when(
        () => electrum.checkServersInUseAreOnlineForNetwork(any()),
      ).thenAnswer((_) async => true);
      final getIndexPrice = FakeIndexPriceReader(
        failure: const PricerNetworkFailure('Pricer probe failed'),
      );
      final feesRepository = _MockFeesRepository();
      when(
        () => feesRepository.getNetworkFees(network: any(named: 'network')),
      ).thenAnswer((_) async => throw Exception('Mempool probe failed'));
      final payjoinPolicy = _MockPayjoinPolicyAccess();
      when(payjoinPolicy.load).thenAnswer((_) async => Ok(_allPayjoinOff()));
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
        getIndexPrice: getIndexPrice.call,
        payjoinPolicy: payjoinPolicy,
        payjoinDiagnostics: _MockPayjoinDiagnostics(),
        feesRepository: feesRepository,
        walletRepository: walletRepository,
        ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
        checkServerConnection: () async => const Ok(false),
        settingsRepository: settingsRepository,
        tor: tor,
      );

      final status = await usecase.execute(network: Network.bitcoinMainnet);

      expect(status.tor.status, ServiceStatus.offline);
      verifyNever(walletRepository.isTorRequired);
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
      final getIndexPrice = FakeIndexPriceReader(
        failure: const PricerNetworkFailure('Pricer probe failed'),
      );
      final feesRepository = _MockFeesRepository();
      when(
        () => feesRepository.getNetworkFees(network: any(named: 'network')),
      ).thenAnswer((_) async => throw Exception('Mempool probe failed'));

      final walletRepository = _MockWalletRepository();
      when(walletRepository.isTorRequired).thenAnswer((_) async => false);
      final settingsRepository = _MockSettingsRepository();
      when(
        () => settingsRepository.fetch(),
      ).thenAnswer((_) async => _settings(useTorProxy: false));
      final payjoinPolicy = _MockPayjoinPolicyAccess();
      when(payjoinPolicy.load).thenAnswer((_) async => Ok(_allPayjoinOff()));

      final usecase = CheckAllServiceStatusUsecase(
        electrumConnectivityPort: electrum,
        getIndexPrice: getIndexPrice.call,
        payjoinPolicy: payjoinPolicy,
        payjoinDiagnostics: _MockPayjoinDiagnostics(),
        feesRepository: feesRepository,
        walletRepository: walletRepository,
        ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
        checkServerConnection: () async => const Ok(false),
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
    final getIndexPrice = FakeIndexPriceReader(
      failure: const PricerNetworkFailure('Pricer probe failed'),
    );
    final feesRepository = _MockFeesRepository();
    when(
      () => feesRepository.getNetworkFees(network: any(named: 'network')),
    ).thenAnswer((_) async => throw Exception('Mempool probe failed'));

    final walletRepository = _MockWalletRepository();
    when(walletRepository.isTorRequired).thenAnswer((_) async => false);
    final settingsRepository = _MockSettingsRepository();
    when(settingsRepository.fetch).thenThrow(Exception('Tor probe failed'));
    final payjoinPolicy = _MockPayjoinPolicyAccess();
    when(payjoinPolicy.load).thenAnswer((_) async => Ok(_allPayjoinOff()));

    final updates = <AllServicesStatus>[];
    final usecase = CheckAllServiceStatusUsecase(
      electrumConnectivityPort: electrum,
      getIndexPrice: getIndexPrice.call,
      payjoinPolicy: payjoinPolicy,
      payjoinDiagnostics: _MockPayjoinDiagnostics(),
      feesRepository: feesRepository,
      walletRepository: walletRepository,
      ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
      checkServerConnection: () async => const Ok(false),
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
      final getIndexPrice = FakeIndexPriceReader(
        failure: const PricerNetworkFailure('Pricer probe failed'),
      );
      final feesRepository = _MockFeesRepository();
      when(
        () => feesRepository.getNetworkFees(network: any(named: 'network')),
      ).thenAnswer((_) async => throw Exception('Mempool probe failed'));
      final payjoinPolicy = _MockPayjoinPolicyAccess();
      when(payjoinPolicy.load).thenAnswer((_) async => Ok(_allPayjoinOff()));
      final walletRepository = _MockWalletRepository();
      when(walletRepository.isTorRequired).thenAnswer((_) async => false);
      final settingsRepository = _MockSettingsRepository();
      when(
        () => settingsRepository.fetch(),
      ).thenAnswer((_) async => _settings(useTorProxy: false));

      final usecase = CheckAllServiceStatusUsecase(
        electrumConnectivityPort: electrum,
        getIndexPrice: getIndexPrice.call,
        payjoinPolicy: payjoinPolicy,
        payjoinDiagnostics: _MockPayjoinDiagnostics(),
        feesRepository: feesRepository,
        walletRepository: walletRepository,
        ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
        checkServerConnection: () async => const Ok(false),
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
    final getIndexPrice = FakeIndexPriceReader(
      failure: const PricerNetworkFailure('Pricer probe failed'),
    );
    final feesRepository = _MockFeesRepository();
    when(
      () => feesRepository.getNetworkFees(network: any(named: 'network')),
    ).thenAnswer((_) async => throw Exception('Mempool probe failed'));
    final payjoinPolicy = _MockPayjoinPolicyAccess();
    when(payjoinPolicy.load).thenAnswer((_) async => Ok(_allPayjoinOff()));
    final walletRepository = _MockWalletRepository();
    when(walletRepository.isTorRequired).thenAnswer((_) async => false);
    final settingsRepository = _MockSettingsRepository();
    when(
      () => settingsRepository.fetch(),
    ).thenAnswer((_) async => _settings(useTorProxy: false));

    final usecase = CheckAllServiceStatusUsecase(
      electrumConnectivityPort: electrum,
      getIndexPrice: getIndexPrice.call,
      payjoinPolicy: payjoinPolicy,
      payjoinDiagnostics: _MockPayjoinDiagnostics(),
      feesRepository: feesRepository,
      walletRepository: walletRepository,
      ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
      checkServerConnection: () async => const Ok(false),
      settingsRepository: settingsRepository,
      tor: _MockTor(),
    );

    await expectLater(
      usecase.execute(network: Network.bitcoinMainnet),
      throwsA(isA<StateError>()),
    );
  });
  group('Data Backup server reachability', () {
    final origin = Uri.parse('https://backup.test');
    final endpoint = origin.resolve('/api/v1/wallet-backups/fetch');
    const invalidRequest = '{"code":"BackupInvalidRequest","status":"ERROR"}';
    for (final (code, type, body, expected) in [
      (400, 'application/json', invalidRequest, ServiceStatus.online),
      (400, 'text/html', '<html>bad request</html>', ServiceStatus.offline),
      (
        400,
        'application/json',
        '{"code":"Other","status":"ERROR"}',
        ServiceStatus.offline,
      ),
      (
        400,
        'application/json',
        '{"code":"BackupInvalidRequest","status":"OK"}',
        ServiceStatus.offline,
      ),
      (400, 'application/json', 'not json', ServiceStatus.offline),
      (200, 'application/json', invalidRequest, ServiceStatus.offline),
      (500, 'application/json', invalidRequest, ServiceStatus.offline),
      (302, 'application/json', invalidRequest, ServiceStatus.offline),
      (
        400,
        'application/json',
        '${' ' * 4096}$invalidRequest',
        ServiceStatus.offline,
      ),
    ]) {
      test('HTTP $code / $type / ${body.length} bytes: $expected', () async {
        final client = _ProbeClient();
        final request = _ProbeRequest();
        final headers = _ProbeHeaders();
        final response = _ProbeResponse(Stream.value(utf8.encode(body)));
        when(() => client.postUrl(endpoint)).thenAnswer((_) async => request);
        when(() => request.headers).thenReturn(headers);
        when(() => request.close()).thenAnswer((_) async => response);
        when(() => response.statusCode).thenReturn(code);
        when(() => response.headers).thenReturn(headers);
        when(() => headers.contentType).thenReturn(ContentType.parse(type));
        final updates = <AllServicesStatus>[];
        final result = await HttpOverrides.runZoned(
          () => _backupProbeUsecase().execute(
            network: Network.bitcoinMainnet,
            backupServerOrigin: origin,
            onUpdate: updates.add,
          ),
          createHttpClient: (_) => client,
        );
        expect(result.backupServer.status, expected);
        expect(result.backupServer.lastChecked, isNotNull);
        expect(updates.any((s) => s.backupServer.status == expected), isTrue);
        verify(() => client.postUrl(endpoint)).called(1);
        verify(() => request.write('{}')).called(1);
        verify(() => request.followRedirects = false).called(1);
        verify(() => headers.contentType = ContentType.json).called(1);
        verify(() => client.close(force: true)).called(1);
      });
    }

    test('a hung request reports offline and closes its client', () async {
      final client = _ProbeClient();
      final request = _ProbeRequest();
      when(() => client.postUrl(endpoint)).thenAnswer((_) async => request);
      when(() => request.headers).thenReturn(_ProbeHeaders());
      when(
        () => request.close(),
      ).thenAnswer((_) => Completer<HttpClientResponse>().future);
      final result = await HttpOverrides.runZoned(
        () => _backupProbeUsecase().execute(
          network: Network.bitcoinMainnet,
          backupServerOrigin: origin,
        ),
        createHttpClient: (_) => client,
      ).timeout(const Duration(seconds: 15));
      expect(result.backupServer.status, ServiceStatus.offline);
      verify(() => client.close(force: true)).called(1);
    });

    test('backup server failure participates in the aggregate status', () {
      const online = ServiceStatusInfo(
        status: ServiceStatus.online,
        name: 'fixture',
      );
      const all = AllServicesStatus(
        internetConnection: online,
        bitcoinElectrum: online,
        liquidElectrum: online,
        payjoin: online,
        pricer: online,
        mempool: online,
        tor: online,
        recoverbull: online,
        backupServer: online,
      );
      expect(all.allServicesOnline, isTrue);
      expect(
        all
            .copyWith(
              backupServer: online.copyWith(status: ServiceStatus.offline),
            )
            .allServicesOnline,
        isFalse,
      );
    });
  });
}

/// Send and the exchange switches ship on, so payjoin is unused only with all
/// four off.
PayjoinPolicy _allPayjoinOff() => PayjoinPolicy.defaults()
    .withAction(PayjoinAction.send, enabled: false)
    .withAction(PayjoinAction.buy, enabled: false)
    .withAction(PayjoinAction.sell, enabled: false);
