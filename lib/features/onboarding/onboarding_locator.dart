import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/apply_pending_wizard_choices_after_wallet_creation_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/create_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/recover_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/wizard/public/wizard_facade.dart';
import 'package:get_it/get_it.dart';

class OnboardingLocator {
  static void setup(GetIt locator) {
    // Blocs
    locator.registerFactory<OnboardingBloc>(
      () => OnboardingBloc(
        createOnboardingWalletUsecase: locator<CreateOnboardingWalletUsecase>(),
        recoverOnboardingWalletUsecase:
            locator<RecoverOnboardingWalletUsecase>(),
        applyPendingWizardChoices:
            ApplyPendingWizardChoicesAfterWalletCreationUsecase(
              locator<WizardFacade>(),
            ),
      ),
    );

    // Usecases
    locator.registerFactory<CompletePhysicalBackupVerificationUsecase>(
      () => CompletePhysicalBackupVerificationUsecase(
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<CreateOnboardingWalletUsecase>(
      () => CreateOnboardingWalletUsecase(
        createDefaultWalletsUsecase: locator<CreateDefaultWalletsUsecase>(),
      ),
    );

    locator.registerFactory<RecoverOnboardingWalletUsecase>(
      () => RecoverOnboardingWalletUsecase(
        createDefaultWalletsUsecase: locator<CreateDefaultWalletsUsecase>(),
        completePhysicalBackupVerificationUsecase:
            locator<CompletePhysicalBackupVerificationUsecase>(),
      ),
    );
  }
}
