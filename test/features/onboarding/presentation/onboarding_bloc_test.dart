import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/create_onboarding_wallets_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCreateOnboardingWalletsUsecase extends Mock
    implements CreateOnboardingWalletsUsecase {}

class _MockCompletePhysicalBackupVerificationUsecase extends Mock
    implements CompletePhysicalBackupVerificationUsecase {}

class _MockWallet extends Mock implements Wallet {}

void main() {
  late _MockCreateOnboardingWalletsUsecase createWallets;
  late _MockCompletePhysicalBackupVerificationUsecase completeVerification;
  late OnboardingBloc bloc;

  setUp(() {
    createWallets = _MockCreateOnboardingWalletsUsecase();
    completeVerification = _MockCompletePhysicalBackupVerificationUsecase();
    bloc = OnboardingBloc(
      createOnboardingWalletsUsecase: createWallets,
      completePhysicalBackupVerificationUsecase: completeVerification,
    );
  });

  tearDown(() => bloc.close());

  test(
    'wallet recovery succeeds when only backup verification persistence fails',
    () async {
      final mnemonic = (
        words: List.generate(11, (_) => 'zoo') + ['wrong'],
        passphrase: '',
        label: '',
        language: bip39.Language.english,
      );
      final wallet = _MockWallet();
      when(() => wallet.masterFingerprint).thenReturn('f00dbabe');
      when(
        () => createWallets.execute(mnemonicWords: any(named: 'mnemonicWords')),
      ).thenAnswer((_) async => Ok([wallet]));
      when(
        () => completeVerification.execute(masterFingerprint: 'f00dbabe'),
      ).thenAnswer(
        (_) async => const Err(
          OnboardingBackupVerificationPersistenceFailure('storage detail'),
        ),
      );

      final terminalState = bloc.stream.firstWhere((state) => state.isSuccess);
      bloc.add(OnboardingRecoverWalletClicked(mnemonic: mnemonic));

      final state = await terminalState;
      expect(state.step, OnboardingStep.recover);
      expect(
        state.failure,
        isA<OnboardingBackupVerificationPersistenceFailure>(),
      );
    },
  );
}
