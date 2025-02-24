import 'package:bb_mobile/app_locator.dart';
import 'package:bb_mobile/core/data/datasources/bip39_word_list_data_source.dart';
import 'package:bb_mobile/core/data/datasources/exchange_data_source.dart';
import 'package:bb_mobile/core/data/datasources/key_value_storage/impl/hive_storage_datasource_impl.dart';
import 'package:bb_mobile/core/data/datasources/key_value_storage/impl/secure_storage_data_source_impl.dart';
import 'package:bb_mobile/core/data/datasources/key_value_storage/key_value_storage_data_source.dart';
import 'package:bb_mobile/core/data/repositories/seed_repository_impl.dart';
import 'package:bb_mobile/core/data/repositories/settings_repository_impl.dart';
import 'package:bb_mobile/core/data/repositories/hive_wallet_metadata_repository_impl.dart';
import 'package:bb_mobile/core/data/repositories/word_list_repository_impl.dart';
import 'package:bb_mobile/core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/core/domain/repositories/word_list_repository.dart';
import 'package:bb_mobile/core/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/core/domain/services/wallet_metadata_derivation_service.dart';
import 'package:bb_mobile/core/domain/services/wallet_repository_manager.dart';
import 'package:bb_mobile/core/domain/usecases/find_mnemonic_words_use_case.dart';
import 'package:bb_mobile/core/domain/usecases/get_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_environment_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_language_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_wallet_balance_sat_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_wallets_usecase.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

class CoreLocator {
  static const String secureStorageInstanceName = 'secureStorage';
  static const String hiveSettingsBoxName = 'settings';
  static const String settingsStorageInstanceName = 'settingsStorage';
  static const String bullBitcoinExchangeInstanceName = 'bullBitcoinExchange';
  static const String hiveWalletsBoxName = 'wallets';
  static const String walletsStorageInstanceName = 'walletsStorage';

  static Future<void> setup() async {
    // Data sources
    locator.registerLazySingleton<KeyValueStorageDataSource<String>>(
      () => SecureStorageDataSourceImpl(
        const FlutterSecureStorage(),
      ),
      instanceName: secureStorageInstanceName,
    );
    final settingsBox = await Hive.openBox<String>(hiveSettingsBoxName);
    locator.registerLazySingleton<KeyValueStorageDataSource<String>>(
      () => HiveStorageDataSourceImpl<String>(settingsBox),
      instanceName: settingsStorageInstanceName,
    );
    locator.registerLazySingleton<ExchangeDataSource>(
      () => BullBitcoinExchangeDataSourceImpl(),
      instanceName: bullBitcoinExchangeInstanceName,
    );
    final walletsBox = await Hive.openBox<String>(hiveWalletsBoxName);
    locator.registerLazySingleton<KeyValueStorageDataSource<String>>(
      () => HiveStorageDataSourceImpl<String>(walletsBox),
      instanceName: walletsStorageInstanceName,
    );
    locator.registerLazySingleton<Bip39WordListDataSource>(
      () => Bip39EnglishWordListDataSourceImpl(),
    );

    // Repositories
    locator.registerLazySingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(
        storage: locator<KeyValueStorageDataSource<String>>(
          instanceName: CoreLocator.settingsStorageInstanceName,
        ),
      ),
    );
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
    locator.registerLazySingleton<WordListRepository>(
      () => WordListRepositoryImpl(
        dataSource: locator<Bip39WordListDataSource>(),
      ),
    );

    // Managers or services responsible for handling specific logic
    locator.registerLazySingleton<WalletMetadataDerivationService>(
      () => const WalletMetadataDerivationServiceImpl(),
    );
    locator.registerLazySingleton<WalletRepositoryManager>(
      () => WalletRepositoryManagerImpl(),
    );
    locator.registerLazySingleton<MnemonicSeedFactory>(
      () => const MnemonicSeedFactoryImpl(),
    );

    // Use cases
    locator.registerFactory<FindMnemonicWordsUseCase>(
      () => FindMnemonicWordsUseCase(
        wordListRepository: locator<WordListRepository>(),
      ),
    );
    locator.registerFactory<GetEnvironmentUseCase>(
      () => GetEnvironmentUseCase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<GetBitcoinUnitUseCase>(
      () => GetBitcoinUnitUseCase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<GetLanguageUseCase>(
      () => GetLanguageUseCase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<GetWalletsUseCase>(
      () => GetWalletsUseCase(
        walletRepositoryManager: locator<WalletRepositoryManager>(),
        walletMetadataRepository: locator<WalletMetadataRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<GetWalletBalanceSatUseCase>(
      () => GetWalletBalanceSatUseCase(
        walletRepositoryManager: locator<WalletRepositoryManager>(),
      ),
    );
  }
}
