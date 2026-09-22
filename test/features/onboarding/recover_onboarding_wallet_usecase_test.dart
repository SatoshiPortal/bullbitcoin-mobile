import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
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

class _GetWallets extends Mock implements GetWalletsUsecase {}

void main() {
  late _GetWallets getWallets;
  late _MockCreateDefaultWalletsUsecase createDefaultWalletsUsecase;
  late _MockCompletePhysicalBackupVerificationUsecase
  completePhysicalBackupVerificationUsecase;
  late RecoverOnboardingWalletUsecase usecase;

  const mnemonicWords = ['abandon', 'ability'];

  setUp(() {
    createDefaultWalletsUsecase = _MockCreateDefaultWalletsUsecase();
    completePhysicalBackupVerificationUsecase =
        _MockCompletePhysicalBackupVerificationUsecase();
    getWallets = _GetWallets();
    when(
      () => getWallets.execute(includeHidden: true),
    ).thenAnswer((_) async => []);
    usecase = RecoverOnboardingWalletUsecase(
      getWallets: getWallets,
      createDefaultWalletsUsecase: createDefaultWalletsUsecase,
      completePhysicalBackupVerificationUsecase:
          completePhysicalBackupVerificationUsecase,
    );

    registerFallbackValue(<String>[]);
  });

  Wallet wallet(String id, String? label) => Wallet(
    origin: id,
    label: label,
    network: Network.bitcoinMainnet,
    isDefault: true,
    signers: [],
    scriptType: ScriptType.bip84,
    publicDescriptor: 'fixture-descriptor-$id',
    balanceSat: BigInt.zero,
  );
  test(
    'records only new wallet labels without changing the shared creation contract',
    () async {
      final existing = wallet('existing', 'Keep mine');
      final created = wallet('new', null);
      when(
        () => getWallets.execute(includeHidden: true),
      ).thenAnswer((_) async => [existing]);
      when(
        () => createDefaultWalletsUsecase.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
        ),
      ).thenAnswer((_) async => [existing, created]);
      when(
        () => completePhysicalBackupVerificationUsecase.execute(),
      ).thenAnswer((_) async {});
      final result = await usecase.execute(mnemonicWords: mnemonicWords);
      expect((result as Ok<Map<String, String?>, OnboardingFailure>).value, {
        'new': null,
      });
      verifyInOrder([
        () => getWallets.execute(includeHidden: true),
        () => createDefaultWalletsUsecase.execute(mnemonicWords: mnemonicWords),
      ]);
    },
  );
  test('an empty install is a valid starting point for recovery', () async {
    when(
      () => getWallets.execute(includeHidden: true),
    ).thenThrow(NoWalletsFoundException('empty fixture'));
    when(
      () => createDefaultWalletsUsecase.execute(
        mnemonicWords: any(named: 'mnemonicWords'),
      ),
    ).thenAnswer((_) async => [wallet('new', 'Initial name')]);
    when(
      () => completePhysicalBackupVerificationUsecase.execute(),
    ).thenAnswer((_) async {});
    final result = await usecase.execute(mnemonicWords: mnemonicWords);
    expect((result as Ok<Map<String, String?>, OnboardingFailure>).value, {
      'new': 'Initial name',
    });
  });
  group('RecoverOnboardingWalletUsecase', () {
    test(
      'maps a foreign wallet-setup failure during recovery to OnboardingWalletSetupFailure '
      'without leaking the raw exception',
      () async {
        when(
          () => createDefaultWalletsUsecase.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
          ),
        ).thenThrow(Exception('BDK: invalid mnemonic checksum'));

        final result = await usecase.execute(mnemonicWords: mnemonicWords);

        expect(result, isA<Err<Map<String, String?>, OnboardingFailure>>());
        final failure =
            (result as Err<Map<String, String?>, OnboardingFailure>).failure;
        expect(failure, isA<OnboardingWalletSetupFailure>());
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

        expect(result, isA<Err<Map<String, String?>, OnboardingFailure>>());
        final failure =
            (result as Err<Map<String, String?>, OnboardingFailure>).failure;
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

      expect(result, isA<Ok<Map<String, String?>, OnboardingFailure>>());
    });
  });
}
