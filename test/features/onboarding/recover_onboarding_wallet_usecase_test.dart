import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/public/default_wallets_facade.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/recover_onboarding_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCreateDefaultWalletsUsecase extends Mock
    implements CreateDefaultWalletsUsecase {}

class _MockCompletePhysicalBackupVerificationUsecase extends Mock
    implements CompletePhysicalBackupVerificationUsecase {}

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _Wallet extends Mock implements Wallet {}

void main() {
  late _MockCreateDefaultWalletsUsecase createDefaultWalletsUsecase;
  late _MockGetWalletsUsecase getWallets;
  late _MockCompletePhysicalBackupVerificationUsecase
  completePhysicalBackupVerificationUsecase;
  late RecoverOnboardingWalletUsecase usecase;

  const mnemonicWords = ['abandon', 'ability'];

  setUp(() {
    createDefaultWalletsUsecase = _MockCreateDefaultWalletsUsecase();
    getWallets = _MockGetWalletsUsecase();
    when(() => getWallets.execute(includeHidden: true))
        .thenAnswer((_) async => const Err(NoWalletsFoundFailure()));
    completePhysicalBackupVerificationUsecase =
        _MockCompletePhysicalBackupVerificationUsecase();
    usecase = RecoverOnboardingWalletUsecase(
      defaultWallets: DefaultWalletsFacade(
        createDefaultWalletsUsecase,
        getWallets: getWallets,
      ),
      completePhysicalBackupVerificationUsecase:
          completePhysicalBackupVerificationUsecase,
    );

    registerFallbackValue(<String>[]);
  });

  group('RecoverOnboardingWalletUsecase', () {
    test(
      'does not restore when existing wallet labels cannot be read',
      () async {
        when(() => getWallets.execute(includeHidden: true))
            .thenAnswer((_) async => const Err(WalletStorageFailure()));

        expect(
          await usecase.execute(mnemonicWords: mnemonicWords),
          isA<Err<Map<String, String?>, OnboardingFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<OnboardingWalletSetupFailure>(),
          ),
        );
        verifyZeroInteractions(createDefaultWalletsUsecase);
        verifyZeroInteractions(completePhysicalBackupVerificationUsecase);
      },
    );

    test('maps a foreign wallet-setup failure during recovery to OnboardingWalletSetupFailure '
        'without leaking the raw exception', () async {
      when(
        () => createDefaultWalletsUsecase.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: '',
        ),
      ).thenAnswer((_) async => const Err(DefaultWalletCreationFailure()));

      final result = await usecase.execute(mnemonicWords: mnemonicWords);

      expect(result, isA<Err<Map<String, String?>, OnboardingFailure>>());
      final failure =
          (result as Err<Map<String, String?>, OnboardingFailure>).failure;
      expect(failure, isA<OnboardingWalletSetupFailure>());
      expect(failure.logMessage, isNull);
      verifyNever(() => completePhysicalBackupVerificationUsecase.execute());
    });

    test(
      'maps a foreign backup-verification failure to '
      'OnboardingBackupVerificationFailure without leaking the raw exception',
      () async {
        when(
          () => createDefaultWalletsUsecase.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
            passphrase: '',
          ),
        ).thenAnswer((_) async => const Ok([]));
        when(() => completePhysicalBackupVerificationUsecase.execute())
            .thenThrow(Exception('No default wallet found'));

        final result = await usecase.execute(mnemonicWords: mnemonicWords);

        expect(result, isA<Err<Map<String, String?>, OnboardingFailure>>());
        final failure =
            (result as Err<Map<String, String?>, OnboardingFailure>).failure;
        expect(failure, isA<OnboardingBackupVerificationFailure>());
        expect(failure.logMessage, isNull);
      },
    );

    test('forwards the passphrase without changing spaces or case', () async {
      const passphrase = ' Mixed Case ';
      when(
        () => createDefaultWalletsUsecase.execute(
          mnemonicWords: mnemonicWords,
          passphrase: passphrase,
        ),
      ).thenAnswer((_) async => const Ok([]));
      when(() => completePhysicalBackupVerificationUsecase.execute())
          .thenAnswer((_) async {});
      expect(
        await usecase.execute(
          mnemonicWords: mnemonicWords,
          passphrase: passphrase,
        ),
        isA<Ok<Map<String, String?>, OnboardingFailure>>(),
      );
      verify(
        () => createDefaultWalletsUsecase.execute(
          mnemonicWords: mnemonicWords,
          passphrase: passphrase,
        ),
      ).called(1);
    });

    test('returns initial labels only for newly restored wallets', () async {
      final existing = _Wallet();
      final restored = _Wallet();
      when(() => existing.id).thenReturn('existing');
      when(() => restored.id).thenReturn('restored');
      when(() => restored.label).thenReturn('Restored Bitcoin');
      when(() => getWallets.execute(includeHidden: true))
          .thenAnswer((_) async => Ok([existing]));
      when(
        () => createDefaultWalletsUsecase.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
        ),
      ).thenAnswer((_) async => Ok([existing, restored]));
      when(() => completePhysicalBackupVerificationUsecase.execute())
          .thenAnswer((_) async {});

      final result = await usecase.execute(mnemonicWords: mnemonicWords);

      expect(
        result,
        isA<Ok<Map<String, String?>, OnboardingFailure>>().having(
          (result) => result.value,
          'initial labels',
          {'restored': 'Restored Bitcoin'},
        ),
      );
    });
  });
}
