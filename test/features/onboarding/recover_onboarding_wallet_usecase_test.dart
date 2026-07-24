import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/recover_onboarding_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCreateDefaultWalletsUsecase extends Mock
    implements CreateDefaultWalletsUsecase {}

class _MockCompletePhysicalBackupVerificationUsecase extends Mock
    implements CompletePhysicalBackupVerificationUsecase {}

void main() {
  late _MockCreateDefaultWalletsUsecase createDefaultWalletsUsecase;
  late _MockCompletePhysicalBackupVerificationUsecase
  completePhysicalBackupVerificationUsecase;
  late RecoverOnboardingWalletUsecase usecase;

  const mnemonicWords = ['abandon', 'ability'];

  setUp(() {
    createDefaultWalletsUsecase = _MockCreateDefaultWalletsUsecase();
    completePhysicalBackupVerificationUsecase =
        _MockCompletePhysicalBackupVerificationUsecase();
    usecase = RecoverOnboardingWalletUsecase(
      createDefaultWalletsUsecase: createDefaultWalletsUsecase,
      completePhysicalBackupVerificationUsecase:
          completePhysicalBackupVerificationUsecase,
    );

    registerFallbackValue(<String>[]);
  });

  group('RecoverOnboardingWalletUsecase', () {
    test(
      'maps a foreign wallet-recovery failure to OnboardingWalletCreationFailure '
      'without leaking the raw exception',
      () async {
        when(
          () => createDefaultWalletsUsecase.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
          ),
        ).thenThrow(Exception('BDK: invalid mnemonic checksum'));

        final result = await usecase.execute(mnemonicWords: mnemonicWords);

        expect(result, isA<Err<void, OnboardingFailure>>());
        final failure = (result as Err<void, OnboardingFailure>).failure;
        expect(failure, isA<OnboardingWalletCreationFailure>());
        expect(failure.logMessage, isNull);
        verifyNever(() => completePhysicalBackupVerificationUsecase.execute());
      },
    );

    test(
      'maps a foreign backup-verification failure to '
      'OnboardingBackupVerificationFailure without leaking the raw exception',
      () async {
        when(
          () => createDefaultWalletsUsecase.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
          ),
        ).thenAnswer((_) async => []);
        when(
          () => completePhysicalBackupVerificationUsecase.execute(),
        ).thenThrow(Exception('No default wallet found'));

        final result = await usecase.execute(mnemonicWords: mnemonicWords);

        expect(result, isA<Err<void, OnboardingFailure>>());
        final failure = (result as Err<void, OnboardingFailure>).failure;
        expect(failure, isA<OnboardingBackupVerificationFailure>());
        expect(failure.logMessage, isNull);
      },
    );

    test('returns Ok on success', () async {
      when(
        () => createDefaultWalletsUsecase.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
        ),
      ).thenAnswer((_) async => []);
      when(
        () => completePhysicalBackupVerificationUsecase.execute(),
      ).thenAnswer((_) async {});

      final result = await usecase.execute(mnemonicWords: mnemonicWords);

      expect(result, isA<Ok<void, OnboardingFailure>>());
    });
  });
}
