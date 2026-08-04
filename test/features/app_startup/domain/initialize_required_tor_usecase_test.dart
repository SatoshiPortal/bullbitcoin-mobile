import 'package:bb_mobile/features/app_startup/domain/app_startup_wallet_port.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/initialize_required_tor_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_tor/tor.dart';

class _MockAppStartupWalletPort extends Mock implements AppStartupWalletPort {}

class _MockEnsureTorReadyUsecase extends Mock
    implements EnsureTorReadyUsecase {}

void main() {
  late _MockAppStartupWalletPort walletPort;
  late _MockEnsureTorReadyUsecase ensureTorReadyUsecase;
  late InitializeRequiredTorUsecase usecase;

  setUp(() {
    walletPort = _MockAppStartupWalletPort();
    ensureTorReadyUsecase = _MockEnsureTorReadyUsecase();
    usecase = InitializeRequiredTorUsecase(walletPort, ensureTorReadyUsecase);
  });

  test('does not start embedded Tor without an encrypted backup', () async {
    when(
      () => walletPort.hasMainnetBitcoinEncryptedBackup(),
    ).thenAnswer((_) async => false);

    expect(await usecase.execute(), isNull);
    verifyNever(() => ensureTorReadyUsecase.execute());
  });

  test('starts embedded Tor when an encrypted backup exists', () async {
    final route = TorRoute(
      source: TorSource.embedded,
      endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
      evidence: TorReadinessEvidence.embeddedBootstrap,
    );
    final ready = TorReady(route);
    when(
      () => walletPort.hasMainnetBitcoinEncryptedBackup(),
    ).thenAnswer((_) async => true);
    when(() => ensureTorReadyUsecase.execute()).thenAnswer((_) async => ready);

    expect(await usecase.execute(), same(ready));
    verify(() => ensureTorReadyUsecase.execute()).called(1);
  });
}
