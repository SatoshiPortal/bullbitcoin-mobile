import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/features/wallet/data/repositories/seed_repository_impl.dart';
import 'package:bb_mobile/features/wallet/data/repositories/wallet_metadata_repository_impl.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/features/wallet/domain/services/seed_generator.dart';
import 'package:bb_mobile/features/wallet/domain/services/wallet_repository_manager.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/fetch_all_wallets_metadata_usecase.dart';

void setupWalletDependencies() {
  // Repositories
  locator.registerLazySingleton<WalletMetadataRepository>(
    () => WalletMetadataRepositoryImpl(),
  );
  locator.registerLazySingleton<SeedRepository>(
    () => SeedRepositoryImpl(),
  );

  // Managers or services responsible for handling specific logic
  locator.registerLazySingleton<SeedGenerator>(
    () => const BdkSeedGeneratorImpl(),
  );
  locator.registerLazySingleton<WalletRepositoryManager>(
    () => WalletRepositoryManagerImpl(),
  );

  // Use cases
  locator.registerFactory<FetchAllWalletsMetadataUseCase>(
    () => FetchAllWalletsMetadataUseCase(
      walletMetadataRepository: locator<WalletMetadataRepository>(),
    ),
  );
}
