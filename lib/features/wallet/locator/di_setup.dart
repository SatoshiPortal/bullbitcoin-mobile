import 'package:bb_mobile/core/data/datasources/impl/hive_storage_datasource_impl.dart';
import 'package:bb_mobile/core/data/datasources/key_value_storage_data_source.dart';
import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/features/wallet/data/repositories/seed_repository_impl.dart';
import 'package:bb_mobile/features/wallet/data/repositories/wallet_metadata_repository_impl.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/features/wallet/domain/services/mnemonic_generator.dart';
import 'package:bb_mobile/features/wallet/domain/services/wallet_derivation_service.dart';
import 'package:bb_mobile/features/wallet/domain/services/wallet_repository_manager.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/fetch_all_wallets_metadata_usecase.dart';
import 'package:hive/hive.dart';

const String hiveWalletsBoxName = 'wallets';
const String walletsStorageInstanceName = 'walletsStorage';

Future<void> setupWalletDependencies() async {
  // Data sources
  final walletsBox = await Hive.openBox<String>(hiveWalletsBoxName);
  locator.registerLazySingleton<KeyValueStorageDataSource<String>>(
    () => HiveStorageDataSourceImpl<String>(walletsBox),
    instanceName: walletsStorageInstanceName,
  );

  // Repositories
  locator.registerLazySingleton<WalletMetadataRepository>(
    () => HiveWalletMetadataRepositoryImpl(
      locator<KeyValueStorageDataSource<String>>(
        instanceName: walletsStorageInstanceName,
      ),
    ),
  );
  locator.registerLazySingleton<SeedRepository>(
    () => SeedRepositoryImpl(
      locator<KeyValueStorageDataSource<String>>(
        instanceName: secureStorageInstanceName,
      ),
    ),
  );

  // Managers or services responsible for handling specific logic
  locator.registerLazySingleton<MnemonicGenerator>(
    () => const BdkMnemonicGeneratorImpl(),
  );
  locator.registerLazySingleton<WalletDerivationService>(
    () => const WalletDerivationServiceImpl(),
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
