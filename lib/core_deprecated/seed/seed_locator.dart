import 'package:bb_mobile/core_deprecated/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core_deprecated/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core_deprecated/seed/data/repository/word_list_repository.dart';
import 'package:bb_mobile/core_deprecated/seed/data/services/mnemonic_generator.dart';
import 'package:bb_mobile/core_deprecated/seed/domain/usecases/delete_seed_usecase.dart';
import 'package:bb_mobile/core_deprecated/seed/domain/usecases/find_mnemonic_words_usecase.dart';
import 'package:bb_mobile/core_deprecated/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core_deprecated/seed/domain/usecases/process_and_separate_seeds_usecase.dart';
import 'package:bb_mobile/core_deprecated/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core_deprecated/utils/constants.dart';
import 'package:bb_mobile/core_deprecated/wallet/data/repositories/wallet_repository.dart';
import 'package:get_it/get_it.dart';

class SeedLocator {
  static void registerDatasources(GetIt locator) {
    locator.registerLazySingleton<SeedDatasource>(
      () => SeedDatasource(
        secureStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<SeedRepository>(
      () => SeedRepository(source: locator<SeedDatasource>()),
    );

    locator.registerLazySingleton<WordListRepository>(
      () => WordListRepository(),
    );
  }

  static void registerServices(GetIt locator) {
    locator.registerLazySingleton<MnemonicGenerator>(
      () => const MnemonicGenerator(),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<FindMnemonicWordsUsecase>(
      () => FindMnemonicWordsUsecase(
        wordListRepository: locator<WordListRepository>(),
      ),
    );

    locator.registerFactory<GetDefaultSeedUsecase>(
      () => GetDefaultSeedUsecase(
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
      ),
    );

    locator.registerFactory<DeleteSeedUsecase>(
      () => DeleteSeedUsecase(
        seedRepository: locator<SeedRepository>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );

    locator.registerFactory<ProcessAndSeparateSeedsUsecase>(
      () => ProcessAndSeparateSeedsUsecase(),
    );
  }
}
