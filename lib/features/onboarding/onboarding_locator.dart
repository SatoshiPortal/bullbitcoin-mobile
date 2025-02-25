import 'package:bb_mobile/app_locator.dart';
import 'package:bb_mobile/core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/core/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/core/domain/services/wallet_metadata_derivator.dart';
import 'package:bb_mobile/core/domain/services/wallet_repository_manager.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';

class OnboardingLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<CreateDefaultWalletsUseCase>(
      () => CreateDefaultWalletsUseCase(
        settingsRepository: locator<SettingsRepository>(),
        mnemonicSeedFactory: locator<MnemonicSeedFactory>(),
        seedRepository: locator<SeedRepository>(),
        walletMetadataDerivator: locator<WalletMetadataDerivator>(),
        walletMetadataRepository: locator<WalletMetadataRepository>(),
        walletRepositoryManager: locator<WalletRepositoryManager>(),
      ),
    );

    // Blocs
    locator.registerFactory<OnboardingBloc>(
      () => OnboardingBloc(
        createDefaultWalletsUseCase: locator<CreateDefaultWalletsUseCase>(),
      ),
    );
  }
}
