import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_compact_block_filters_available_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/resolve_wallet_birthday_checkpoint_usecase.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:get_it/get_it.dart';

class OnboardingLocator {
  static void setup(GetIt locator) {
    // Blocs
    locator.registerFactory<OnboardingBloc>(
      () => OnboardingBloc(
        createDefaultWalletsUsecase: locator<CreateDefaultWalletsUsecase>(),
        completePhysicalBackupVerificationUsecase:
            locator<CompletePhysicalBackupVerificationUsecase>(),
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        checkCompactBlockFiltersAvailableUsecase:
            locator<CheckCompactBlockFiltersAvailableUsecase>(),
        resolveWalletBirthdayCheckpointUsecase:
            locator<ResolveWalletBirthdayCheckpointUsecase>(),
      ),
    );

    // Usecases
    locator.registerFactory<CompletePhysicalBackupVerificationUsecase>(
      () => CompletePhysicalBackupVerificationUsecase(
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
  }
}
