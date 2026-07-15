import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/create_onboarding_wallets_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:get_it/get_it.dart';

class OnboardingLocator {
  static void setup(GetIt locator) {
    // Blocs
    locator.registerFactory<OnboardingBloc>(
      () => OnboardingBloc(
        createOnboardingWalletsUsecase:
            locator<CreateOnboardingWalletsUsecase>(),
        completePhysicalBackupVerificationUsecase:
            locator<CompletePhysicalBackupVerificationUsecase>(),
      ),
    );

    // Usecases
    locator.registerFactory<CompletePhysicalBackupVerificationUsecase>(
      () => CompletePhysicalBackupVerificationUsecase(
        locator<TestWalletBackupFacade>(),
      ),
    );
    locator.registerFactory<CreateOnboardingWalletsUsecase>(
      () => CreateOnboardingWalletsUsecase(
        locator<CreateDefaultWalletsUsecase>(),
      ),
    );
  }
}
