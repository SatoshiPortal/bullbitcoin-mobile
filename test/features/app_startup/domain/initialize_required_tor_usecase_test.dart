import 'package:bb_mobile/features/app_startup/domain/app_startup_wallet_port.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/initialize_required_tor_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_tor/tor.dart';

class _MockAppStartupWalletPort extends Mock implements AppStartupWalletPort {}

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
  late _MockAppStartupWalletPort walletPort;
  late _MockEnsureTorReadyUsecase ensureTorReadyUsecase;
  late _MockSettingsRepository settingsRepository;
  late _MockTor tor;
  late _MockExternalTor externalTor;
  late InitializeRequiredTorUsecase usecase;

  setUp(() {
    walletPort = _MockAppStartupWalletPort();
    ensureTorReadyUsecase = _MockEnsureTorReadyUsecase();
    settingsRepository = _MockSettingsRepository();
    tor = _MockTor();
    externalTor = _MockExternalTor();
    when(() => tor.external).thenReturn(externalTor);
    usecase = InitializeRequiredTorUsecase(
      walletPort,
      ensureTorReadyUsecase,
      settingsRepository,
      tor,
    );
  });

  test('does not start embedded Tor without an encrypted backup', () async {
    when(
      () => walletPort.hasMainnetBitcoinEncryptedBackup(),
    ).thenAnswer((_) async => false);

    expect(await usecase.execute(), isNull);
    verifyNever(() => settingsRepository.fetch());
    verifyNever(() => ensureTorReadyUsecase.execute());
  });

  test('uses external Tor when it is ready', () async {
    final route = TorRoute(
      source: TorSource.external,
      endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
      evidence: TorReadinessEvidence.externalSocksHandshake,
    );
    when(
      () => walletPort.hasMainnetBitcoinEncryptedBackup(),
    ).thenAnswer((_) async => true);
    when(
      () => walletPort.hasMainnetBitcoinEncryptedBackup(),
    ).thenAnswer((_) async => true);
    when(
      () => settingsRepository.fetch(),
    ).thenAnswer((_) async => _settings(useTorProxy: true));
    when(
      () => externalTor.verify(any()),
    ).thenAnswer((_) async => TorReady(route));

    final state = await usecase.execute();
    expect(state, isA<TorReady>());
    expect((state! as TorReady).route, same(route));
    verifyNever(() => ensureTorReadyUsecase.execute());
  });

  test(
    'does not fall back to embedded Tor when external Tor is unavailable',
    () async {
      final failure = TorExternalProxyUnavailableFailure('offline');
      when(
        () => walletPort.hasMainnetBitcoinEncryptedBackup(),
      ).thenAnswer((_) async => true);
      when(
        () => settingsRepository.fetch(),
      ).thenAnswer((_) async => _settings(useTorProxy: true));
      when(() => externalTor.verify(any())).thenAnswer(
        (_) async =>
            TorUnavailable(source: TorSource.external, failure: failure),
      );

      final state = await usecase.execute();
      expect(state, isA<TorUnavailable>());
      expect((state! as TorUnavailable).source, TorSource.external);
      verifyNever(() => ensureTorReadyUsecase.execute());
    },
  );

  test('starts embedded Tor when external Tor is disabled', () async {
    final ready = const TorUninitialized();
    when(
      () => walletPort.hasMainnetBitcoinEncryptedBackup(),
    ).thenAnswer((_) async => true);
    when(
      () => settingsRepository.fetch(),
    ).thenAnswer((_) async => _settings(useTorProxy: false));
    when(() => ensureTorReadyUsecase.execute()).thenAnswer((_) async => ready);

    expect(await usecase.execute(), same(ready));
    verify(() => ensureTorReadyUsecase.execute()).called(1);
  });
}
