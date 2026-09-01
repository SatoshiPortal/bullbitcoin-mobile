import 'package:bb_mobile/features/onboarding/domain/usecases/create_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/recover_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/apply_pending_wizard_choices_after_wallet_creation_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/wizard/public/wizard_facade.dart'
    show WizardApplyFailure;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockCreateOnboardingWalletUsecase extends Mock
    implements CreateOnboardingWalletUsecase {}

class _MockRecoverOnboardingWalletUsecase extends Mock
    implements RecoverOnboardingWalletUsecase {}

class _MockApplyPendingWizardChoicesUsecase extends Mock
    implements ApplyPendingWizardChoicesAfterWalletCreationUsecase {}

void main() {
  test(
    'retries pending backup opt-in after creating the default wallet',
    () async {
      final createWallets = _MockCreateOnboardingWalletUsecase();
      final applyPending = _MockApplyPendingWizardChoicesUsecase();
      when(() => createWallets.execute()).thenAnswer((_) async => const Ok([]));
      when(
        () => applyPending.execute(),
      ).thenAnswer((_) async => const Ok(null));
      final bloc = OnboardingBloc(
        createOnboardingWalletUsecase: createWallets,
        recoverOnboardingWalletUsecase: _MockRecoverOnboardingWalletUsecase(),
        applyPendingWizardChoices: applyPending,
      );
      addTearDown(bloc.close);

      bloc.add(const OnboardingCreateNewWallet());
      await bloc.stream.firstWhere((state) => state.isSuccess);

      verifyInOrder([
        () => createWallets.execute(),
        () => applyPending.execute(),
      ]);
    },
  );

  test(
    'wallet creation succeeds but exposes a failed Data Backup opt-in',
    () async {
      final createWallets = _MockCreateOnboardingWalletUsecase();
      final applyPending = _MockApplyPendingWizardChoicesUsecase();
      when(() => createWallets.execute()).thenAnswer((_) async => const Ok([]));
      when(
        () => applyPending.execute(),
      ).thenAnswer((_) async => const Err(WizardApplyFailure()));
      final bloc = OnboardingBloc(
        createOnboardingWalletUsecase: createWallets,
        recoverOnboardingWalletUsecase: _MockRecoverOnboardingWalletUsecase(),
        applyPendingWizardChoices: applyPending,
      );
      addTearDown(bloc.close);

      bloc.add(const OnboardingCreateNewWallet());
      final state = await bloc.stream.firstWhere((state) => state.isSuccess);

      expect(state.dataBackupEnableFailed, isTrue);
      expect(state.failure, isNull);
    },
  );
}
