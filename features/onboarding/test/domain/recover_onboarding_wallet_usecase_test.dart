import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';
import 'package:secrets/secrets.dart' show WalletRegistration;
import 'package:onboarding/src/domain/usecases/complete_physical_backup_verification_usecase.dart';
import 'package:onboarding/onboarding.dart';
import 'package:onboarding/src/domain/usecases/recover_onboarding_wallet_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCreateDefaultWalletsUsecase extends Mock
    implements DefaultWalletProvisioning {}

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
      defaultWallets: createDefaultWalletsUsecase,
      completePhysicalBackupVerificationUsecase:
          completePhysicalBackupVerificationUsecase,
    );

    registerFallbackValue(<String>[]);
    registerFallbackValue(<WalletRegistration>[]);
    registerFallbackValue(Language.english);
  });

  group('RecoverOnboardingWalletUsecase', () {
    test('maps a foreign wallet-setup failure during recovery to OnboardingWalletSetupFailure '
        'without leaking the raw exception', () async {
      when(
        () => createDefaultWalletsUsecase.execute(
          language: any(named: 'language'),
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: '',
        ),
      ).thenAnswer((_) async => const Err(DefaultWalletCreationFailure()));

      final result = await usecase.execute(
        mnemonicWords: mnemonicWords,
        language: Language.english,
      );

      expect(result, isA<Err<void, OnboardingFailure>>());
      final failure = (result as Err<void, OnboardingFailure>).failure;
      expect(failure, isA<OnboardingWalletSetupFailure>());
      expect(failure.logMessage, isNull);
      verifyNever(
        () => completePhysicalBackupVerificationUsecase.execute(any()),
      );
    });

    test(
      'forwards a backup-verification failure after the wallets are restored',
      () async {
        when(
          () => createDefaultWalletsUsecase.execute(
            language: any(named: 'language'),
            mnemonicWords: any(named: 'mnemonicWords'),
            passphrase: '',
          ),
        ).thenAnswer((_) async => const Ok([]));
        when(() => completePhysicalBackupVerificationUsecase.execute(any()))
            .thenAnswer(
              (_) async => const Err(OnboardingBackupVerificationFailure()),
            );

        final result = await usecase.execute(
          mnemonicWords: mnemonicWords,
          language: Language.english,
        );

        expect(result, isA<Err<void, OnboardingFailure>>());
        final failure = (result as Err<void, OnboardingFailure>).failure;
        expect(failure, isA<OnboardingBackupVerificationFailure>());
        expect(failure.logMessage, isNull);
      },
    );

    test('forwards the passphrase without changing spaces or case', () async {
      const passphrase = ' Mixed Case ';
      when(
        () => createDefaultWalletsUsecase.execute(
          language: any(named: 'language'),
          mnemonicWords: mnemonicWords,
          passphrase: passphrase,
        ),
      ).thenAnswer((_) async => const Ok([]));
      when(() => completePhysicalBackupVerificationUsecase.execute(any()))
          .thenAnswer((_) async => const Ok(null));
      expect(
        await usecase.execute(
          mnemonicWords: mnemonicWords,
          language: Language.english,
          passphrase: passphrase,
        ),
        isA<Ok<void, OnboardingFailure>>(),
      );
      verify(
        () => createDefaultWalletsUsecase.execute(
          language: any(named: 'language'),
          mnemonicWords: mnemonicWords,
          passphrase: passphrase,
        ),
      ).called(1);
    });

    test('returns Ok on success', () async {
      when(
        () => createDefaultWalletsUsecase.execute(
          language: any(named: 'language'),
          mnemonicWords: any(named: 'mnemonicWords'),
        ),
      ).thenAnswer((_) async => const Ok([]));
      when(() => completePhysicalBackupVerificationUsecase.execute(any()))
          .thenAnswer((_) async => const Ok(null));

      final result = await usecase.execute(
        mnemonicWords: mnemonicWords,
        language: Language.english,
      );

      expect(result, isA<Ok<void, OnboardingFailure>>());
    });
  });
}
