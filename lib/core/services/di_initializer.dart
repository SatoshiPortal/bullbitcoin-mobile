import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/wallet/data/repositories/hive_wallet_metadata_repository.dart';
import 'package:bb_mobile/features/wallet/data/repositories/secure_storage_seed_repository.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/fetch_all_wallets_metadata_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/init_wallets_usecase.dart';
import 'package:get_it/get_it.dart';

GetIt locator = GetIt.instance;

// TODO: call this in the main function before runApp
void setupDI() {
  // TODO: register core datasources here like hive, file storage and secure storage

  locator.registerLazySingleton<WalletMetadataRepository>(
    () => HiveWalletMetadataRepository(),
  );
  locator.registerLazySingleton<SeedRepository>(
      () => SecureStorageSeedRepository());

  locator.registerFactory<FetchAllWalletsMetadataUseCase>(
    () => FetchAllWalletsMetadataUseCase(
      walletMetadataRepository: locator<WalletMetadataRepository>(),
    ),
  );
  locator.registerFactory<InitWalletsUseCase>(
    () => InitWalletsUseCase(
      seedRepository: locator<SeedRepository>(),
      getIt: locator,
    ),
  );

  locator.registerFactory<AppStartupBloc>(
    () => AppStartupBloc(
      fetchAllWalletsMetadataUseCase: locator<FetchAllWalletsMetadataUseCase>(),
      initWalletsUseCase: locator<InitWalletsUseCase>(),
    ),
  );
}
