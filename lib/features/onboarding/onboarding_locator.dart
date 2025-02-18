import 'package:bb_mobile/app_locator.dart';
import 'package:bb_mobile/core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/core/domain/services/wallet_derivation_service.dart';
import 'package:bb_mobile/core/domain/services/wallet_repository_manager.dart';
import 'package:bb_mobile/features/onboarding/domain/services/mnemonic_generator.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';

class OnboardingLocator {
  static void setup() {
    // Services
    locator.registerLazySingleton<MnemonicGenerator>(
      () => const BdkMnemonicGeneratorImpl(),
    );

    // Use cases
    locator.registerFactory<CreateDefaultWalletsUseCase>(
      () => CreateDefaultWalletsUseCase(
        mnemonicGenerator: locator<MnemonicGenerator>(),
        seedRepository: locator<SeedRepository>(),
        walletDerivationService: locator<WalletDerivationService>(),
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
