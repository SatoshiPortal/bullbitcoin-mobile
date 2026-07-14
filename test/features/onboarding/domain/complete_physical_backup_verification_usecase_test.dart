import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/onboarding/domain/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTestWalletBackupFacade extends Mock
    implements TestWalletBackupFacade {}

void main() {
  const fingerprint = 'f00dbabe';
  late _MockTestWalletBackupFacade facade;
  late CompletePhysicalBackupVerificationUsecase usecase;

  setUp(() {
    facade = _MockTestWalletBackupFacade();
    usecase = CompletePhysicalBackupVerificationUsecase(facade);
  });

  test('completes verification through the public backup facade', () async {
    when(
      () => facade.completePhysicalBackupVerification(
        masterFingerprint: fingerprint,
      ),
    ).thenAnswer((_) async => const Ok(null));

    final result = await usecase.execute(masterFingerprint: fingerprint);

    expect(result, isA<Ok>());
    verify(
      () => facade.completePhysicalBackupVerification(
        masterFingerprint: fingerprint,
      ),
    ).called(1);
  });

  test('maps a backup failure into the onboarding failure family', () async {
    when(
      () => facade.completePhysicalBackupVerification(
        masterFingerprint: fingerprint,
      ),
    ).thenAnswer(
      (_) async => const Err(
        TestWalletBackupPersistenceFailure('sensitive storage detail'),
      ),
    );

    final result = await usecase.execute(masterFingerprint: fingerprint);

    expect(
      result,
      isA<Err<void, OnboardingFailure>>().having(
        (result) => result.failure.logMessage,
        'log message',
        'sensitive storage detail',
      ),
    );
  });
}
