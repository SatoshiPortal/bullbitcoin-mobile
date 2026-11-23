import 'package:bull_recoverbull/storage.dart';
import 'package:provisioning/provisioning.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/create_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/recover_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:wallet_import/wallet_import.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/scan_onboarding_wallet_usecase.dart';

class OnboardingLocator {
  static void setup(GetIt locator) {
    // Blocs
    locator.registerFactory<OnboardingBloc>(
      () => OnboardingBloc(
        createOnboardingWalletUsecase: locator<CreateOnboardingWalletUsecase>(),
        scanOnboardingWalletUsecase: locator<ScanOnboardingWalletUsecase>(),
        recoverOnboardingWalletUsecase:
            locator<RecoverOnboardingWalletUsecase>(),
      ),
    );

    locator.registerFactory<ScanOnboardingWalletUsecase>(
      () => ScanOnboardingWalletUsecase(locator<ImportFeature>()),
    );

    // Usecases
    locator.registerFactory<CompletePhysicalBackupVerificationUsecase>(
      () => CompletePhysicalBackupVerificationUsecase(
        backups: locator<RecoverBullWalletBackups>(),
        regtestBackups: locator<RecoverBullWalletBackups>(
          instanceName: 'regtest',
        ),
      ),
    );

    locator.registerFactory<CreateOnboardingWalletUsecase>(
      () => CreateOnboardingWalletUsecase(
        defaultWallets: locator<DefaultWalletProvisioning>(),
      ),
    );

    locator.registerFactory<RecoverOnboardingWalletUsecase>(
      () => RecoverOnboardingWalletUsecase(
        defaultWallets: locator<DefaultWalletProvisioning>(),
        completePhysicalBackupVerificationUsecase:
            locator<CompletePhysicalBackupVerificationUsecase>(),
      ),
    );
  }
}
