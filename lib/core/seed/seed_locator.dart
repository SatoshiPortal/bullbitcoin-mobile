import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository_impl.dart';
import 'package:bb_mobile/core/seed/data/repository/word_list_repository_impl.dart';
import 'package:bb_mobile/core/seed/data/services/mnemonic_generator_impl.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/repositories/word_list_repository.dart';
import 'package:bb_mobile/core/seed/domain/services/mnemonic_generator.dart';
import 'package:bb_mobile/core/seed/domain/usecases/find_mnemonic_words_usecase.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/locator.dart';

class SeedLocator {
  static void registerDatasources() {
    locator.registerLazySingleton<SeedDatasource>(
      () => SeedDatasource(
        secureStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<SeedRepository>(
      () => SeedRepositoryImpl(source: locator<SeedDatasource>()),
    );

    locator.registerLazySingleton<WordListRepository>(
      () => WordListRepositoryImpl(),
    );
  }

  static void registerServices() {
    locator.registerLazySingleton<MnemonicGenerator>(
      () => const MnemonicGeneratorImpl(),
    );
  }

  static void registerUsecases() {
    locator.registerFactory<FindMnemonicWordsUsecase>(
      () => FindMnemonicWordsUsecase(
        wordListRepository: locator<WordListRepository>(),
      ),
    );
  }
}
