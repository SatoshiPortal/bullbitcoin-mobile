import 'package:bb_mobile/app_locator.dart';
import 'package:bb_mobile/core/data/datasources/bip32_data_source.dart';
import 'package:bb_mobile/core/data/datasources/bip39_word_list_data_source.dart';
import 'package:bb_mobile/core/data/datasources/boltz_data_source.dart';
import 'package:bb_mobile/core/data/datasources/descriptor_data_source.dart';
import 'package:bb_mobile/core/data/datasources/exchange_data_source.dart';
import 'package:bb_mobile/core/data/datasources/key_value_stores/impl/hive_storage_datasource_impl.dart';
import 'package:bb_mobile/core/data/datasources/key_value_stores/impl/secure_storage_data_source_impl.dart';
import 'package:bb_mobile/core/data/datasources/key_value_stores/key_value_storage_data_source.dart';
import 'package:bb_mobile/core/data/datasources/pdk_data_source.dart';
import 'package:bb_mobile/core/data/datasources/seed_data_source.dart';
import 'package:bb_mobile/core/data/datasources/wallet_metadata_data_source.dart';
import 'package:bb_mobile/core/data/repositories/boltz_swap_repository_impl.dart';
import 'package:bb_mobile/core/data/repositories/settings_repository_impl.dart';
import 'package:bb_mobile/core/data/repositories/wallet_manager_repository_impl.dart';
import 'package:bb_mobile/core/data/repositories/word_list_repository_impl.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_manager_repository.dart';
import 'package:bb_mobile/core/domain/repositories/word_list_repository.dart';
import 'package:bb_mobile/core/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/core/domain/usecases/find_mnemonic_words_use_case.dart';
import 'package:bb_mobile/core/domain/usecases/get_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_environment_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_language_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_wallets_usecase.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

class CoreLocator {
  static const String secureStorageInstanceName = 'secureStorage';
  static const String hiveSettingsBoxName = 'settings';
  static const String settingsStorageInstanceName = 'settingsStorage';
  static const String bullBitcoinExchangeInstanceName = 'bullBitcoinExchange';
  static const String hiveWalletsBoxName = 'wallets';
  static const String walletsStorageInstanceName = 'walletsStorage';
  static const String boltzInstanceName = 'boltz';
  static const String boltzTestnetInstanceName = 'boltzTestnet';
  static const String boltzSwapRepositoryInstanceName = 'boltzSwapRepository';
  static const String boltzSwapRepositoryTestnetInstanceName =
      'boltzSwapRepositoryTestnet';
  static const String hiveSwapBoxName = 'swaps';
  static const String swapStorageInstanceName = 'swapStorage';

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
    final swapBox = await Hive.openBox<String>(hiveSwapBoxName);
    locator.registerLazySingleton<KeyValueStorageDataSource<String>>(
      () => HiveStorageDataSourceImpl<String>(swapBox),
      instanceName: swapStorageInstanceName,
    );
    locator.registerLazySingleton<Bip39WordListDataSource>(
      () => Bip39EnglishWordListDataSourceImpl(),
    );
    locator.registerLazySingleton<BoltzDataSource>(
      () => BoltzDataSourceImpl(),
      instanceName: boltzInstanceName,
    );
    locator.registerLazySingleton<BoltzDataSource>(
      () => BoltzDataSourceImpl(url: 'api.testnet.boltz.exchange/v2'),
      instanceName: boltzTestnetInstanceName,
    );
    locator.registerLazySingleton<WalletMetadataDataSource>(
      () => WalletMetadataDataSourceImpl(
        bip32: const Bip32DataSourceImpl(),
        descriptor: const DescriptorDataSourceImpl(),
        walletMetadataStorage: locator<KeyValueStorageDataSource<String>>(
          instanceName: walletsStorageInstanceName,
        ),
      ),
    );
    locator.registerLazySingleton<SeedDataSource>(
      () => SeedDataSourceImpl(
        secureStorage: locator<KeyValueStorageDataSource<String>>(
          instanceName: secureStorageInstanceName,
        ),
      ),
    );
    // TODO: We could add a Dio instance with the payjoin directory URL here already
    locator.registerLazySingleton<PdkDataSource>(
      () => PdkDataSourceImpl(dio: Dio()),
    );

    // Repositories
    locator.registerLazySingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(
        storage: locator<KeyValueStorageDataSource<String>>(
          instanceName: CoreLocator.settingsStorageInstanceName,
        ),
      ),
    );
    locator.registerLazySingleton<WalletManagerRepository>(
      () => WalletManagerRepositoryImpl(
        walletMetadataDataSource: locator<WalletMetadataDataSource>(),
        seedDataSource: locator<SeedDataSource>(),
        pdk: locator<PdkDataSource>(),
      ),
    );
    locator.registerLazySingleton<WordListRepository>(
      () => WordListRepositoryImpl(
        dataSource: locator<Bip39WordListDataSource>(),
      ),
    );
    locator.registerLazySingleton<SwapRepository>(
      () => BoltzSwapRepositoryImpl(
        boltz: locator<BoltzDataSource>(instanceName: boltzInstanceName),
        secureStorage: locator<KeyValueStorageDataSource<String>>(
          instanceName: secureStorageInstanceName,
        ),
        localSwapStorage: locator<KeyValueStorageDataSource<String>>(
          instanceName: swapStorageInstanceName,
        ),
      ),
      instanceName: boltzSwapRepositoryInstanceName,
    );
    locator.registerLazySingleton<SwapRepository>(
      () => BoltzSwapRepositoryImpl(
        boltz: locator<BoltzDataSource>(instanceName: boltzTestnetInstanceName),
        secureStorage: locator<KeyValueStorageDataSource<String>>(
          instanceName: secureStorageInstanceName,
        ),
        localSwapStorage: locator<KeyValueStorageDataSource<String>>(
          instanceName: swapStorageInstanceName,
        ),
      ),
      instanceName: boltzSwapRepositoryTestnetInstanceName,
    );

    // Factories, managers or services responsible for handling specific logic
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
        walletManager: locator<WalletManagerRepository>(),
      ),
    );
  }
}
