import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/public/default_wallets_facade.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/create_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/recover_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:bb_mobile/features/import_mnemonic/public/import_mnemonic_scan_facade.dart';
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
      () => ScanOnboardingWalletUsecase(locator<ImportMnemonicScanFacade>()),
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
        defaultWallets: locator<DefaultWalletsFacade>(),
      ),
    );

    locator.registerFactory<RecoverOnboardingWalletUsecase>(
      () => RecoverOnboardingWalletUsecase(
        defaultWallets: locator<DefaultWalletsFacade>(),
        completePhysicalBackupVerificationUsecase:
            locator<CompletePhysicalBackupVerificationUsecase>(),
      ),
    );
  }
}
