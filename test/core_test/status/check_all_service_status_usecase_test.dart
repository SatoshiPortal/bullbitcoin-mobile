import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
import 'package:bb_mobile/core/status/domain/entity/service_status.dart';
import 'package:bb_mobile/core/status/domain/ports/electrum_connectivity_port.dart';
import 'package:bb_mobile/core/status/domain/usecases/check_all_service_status_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
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

class _MockCheckServerConnectionUsecase extends Mock
    implements CheckServerConnectionUsecase {}

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

void main() {
  setUpAll(() {
    registerFallbackValue(TorProxyEndpoint(host: '127.0.0.1', port: 9050));
  });
  test('disabled Payjoin is not probed or reported offline', () async {
    final payjoinPolicy = _MockPayjoinPolicyAccess();
    final payjoinDiagnostics = _MockPayjoinDiagnostics();
    final walletRepository = _MockWalletRepository();
    // Tor is not required for this wallet, so neither the Tor nor the
    // RecoverBull probe is reached — the point of the test is Payjoin.
    when(walletRepository.isTorRequired).thenAnswer((_) async => false);
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
      electrumConnectivityPort: _MockElectrumConnectivityPort(),
      exchangeRateRepository: _MockExchangeRateRepository(),
      payjoinPolicy: payjoinPolicy,
      payjoinDiagnostics: payjoinDiagnostics,
      feesRepository: _MockFeesRepository(),
      walletRepository: walletRepository,
      ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
      checkServerConnectionUsecase: _MockCheckServerConnectionUsecase(),
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
      final walletRepository = _MockWalletRepository();
      when(walletRepository.isTorRequired).thenAnswer((_) async => false);
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
        electrumConnectivityPort: _MockElectrumConnectivityPort(),
        exchangeRateRepository: _MockExchangeRateRepository(),
        payjoinPolicy: _MockPayjoinPolicyAccess(),
        payjoinDiagnostics: _MockPayjoinDiagnostics(),
        feesRepository: _MockFeesRepository(),
        walletRepository: walletRepository,
        ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
        checkServerConnectionUsecase: _MockCheckServerConnectionUsecase(),
        settingsRepository: settingsRepository,
        tor: tor,
      );

      final status = await usecase.execute(network: Network.bitcoinMainnet);

      expect(status.tor.status, ServiceStatus.online);
      verify(walletRepository.isTorRequired).called(1);
    },
  );

  test(
    'reports configured external Tor unavailable without a backup wallet',
    () async {
      final walletRepository = _MockWalletRepository();
      when(walletRepository.isTorRequired).thenAnswer((_) async => false);
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
        electrumConnectivityPort: _MockElectrumConnectivityPort(),
        exchangeRateRepository: _MockExchangeRateRepository(),
        payjoinPolicy: _MockPayjoinPolicyAccess(),
        payjoinDiagnostics: _MockPayjoinDiagnostics(),
        feesRepository: _MockFeesRepository(),
        walletRepository: walletRepository,
        ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
        checkServerConnectionUsecase: _MockCheckServerConnectionUsecase(),
        settingsRepository: settingsRepository,
        tor: tor,
      );

      final status = await usecase.execute(network: Network.bitcoinMainnet);

      expect(status.tor.status, ServiceStatus.offline);
      verify(walletRepository.isTorRequired).called(1);
    },
  );
}
