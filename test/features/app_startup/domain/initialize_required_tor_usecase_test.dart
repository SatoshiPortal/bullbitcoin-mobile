import 'package:bb_mobile/features/app_startup/domain/app_startup_wallet_port.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/initialize_required_tor_usecase.dart';
import 'package:bb_mobile/core/tor/configured_external_tor.dart';
import 'package:bb_mobile/core/tor/resolve_configured_external_tor_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_tor/tor.dart';

class _MockAppStartupWalletPort extends Mock implements AppStartupWalletPort {}

class _MockEnsureTorReadyUsecase extends Mock
    implements EnsureTorReadyUsecase {}

class _MockResolveConfiguredExternalTorUsecase extends Mock
    implements ResolveConfiguredExternalTorUsecase {}

void main() {
  late _MockAppStartupWalletPort walletPort;
  late _MockEnsureTorReadyUsecase ensureTorReadyUsecase;
  late _MockResolveConfiguredExternalTorUsecase resolveExternalTorUsecase;
  late InitializeRequiredTorUsecase usecase;

  setUp(() {
    walletPort = _MockAppStartupWalletPort();
    ensureTorReadyUsecase = _MockEnsureTorReadyUsecase();
    resolveExternalTorUsecase = _MockResolveConfiguredExternalTorUsecase();
    usecase = InitializeRequiredTorUsecase(
      walletPort,
      ensureTorReadyUsecase,
      resolveExternalTorUsecase,
    );
  });

  test('does not start embedded Tor without an encrypted backup', () async {
    when(
      () => walletPort.hasMainnetBitcoinEncryptedBackup(),
    ).thenAnswer((_) async => false);

    expect(await usecase.execute(), isNull);
    verifyNever(() => resolveExternalTorUsecase.execute());
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
      () => resolveExternalTorUsecase.execute(),
    ).thenAnswer((_) async => ConfiguredExternalTorReady(route));

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
        () => resolveExternalTorUsecase.execute(),
      ).thenAnswer((_) async => ConfiguredExternalTorUnavailable(failure));

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
      () => resolveExternalTorUsecase.execute(),
    ).thenAnswer((_) async => const ConfiguredExternalTorDisabled());
    when(() => ensureTorReadyUsecase.execute()).thenAnswer((_) async => ready);

    expect(await usecase.execute(), same(ready));
    verify(() => ensureTorReadyUsecase.execute()).called(1);
  });
}
