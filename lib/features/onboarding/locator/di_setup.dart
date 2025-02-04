import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/features/wallet/domain/services/seed_generator.dart';
import 'package:bb_mobile/features/wallet/domain/services/wallet_repository_manager.dart';

void setupOnboardingDependencies() {
  // Use cases
  locator.registerFactory<CreateDefaultWalletsUseCase>(
    () => CreateDefaultWalletsUseCase(
      seedGenerator: locator<SeedGenerator>(),
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
