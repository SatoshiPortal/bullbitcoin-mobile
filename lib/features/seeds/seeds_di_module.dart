import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/seeds/application/ports/legacy_seed_secret_store_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/mnemonic_generator_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_crypto_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_secret_store_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_usage_repository_port.dart';
import 'package:bb_mobile/features/seeds/application/usecases/create_new_seed_mnemonic_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/delete_seed_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/deregister_seed_usage_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/deregister_seed_usage_with_fingerprint_check_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/get_seed_secret_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/get_seed_usage_by_consumer_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/import_seed_bytes_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/import_seed_mnemonic_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/list_used_seeds_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/load_all_stored_seed_secrets_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/load_legacy_seeds_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/register_seed_usage_usecase.dart';
import 'package:bb_mobile/features/seeds/frameworks/secure_storage/fss_seed_secret_datasource.dart';
import 'package:bb_mobile/features/seeds/interface_adapters/bdk_mnemonic_generator_port.dart';
import 'package:bb_mobile/features/seeds/interface_adapters/bip32_and_39_seed_crypto.dart';
import 'package:bb_mobile/features/seeds/interface_adapters/legacy_seed_secret_store.dart';
import 'package:bb_mobile/features/seeds/interface_adapters/seed_secrets/seed_secret_datasource.dart';
import 'package:bb_mobile/features/seeds/interface_adapters/seed_secrets/seed_secret_store.dart';
import 'package:bb_mobile/features/seeds/interface_adapters/seed_usage/drift_seed_usage_repository.dart';
import 'package:bb_mobile/features/seeds/presentation/blocs/seeds_view_bloc.dart';
import 'package:bb_mobile/features/seeds/public/seeds_facade.dart';

class SeedsDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {
    // Seed secret datasource (Flutter Secure Storage)
    sl.registerLazySingleton<FssSeedSecretDatasource>(
      () => FssSeedSecretDatasource(flutterSecureStorage: sl()),
    );
  }

  @override
  Future<void> registerDrivenAdapters() async {
    // Seed secret datasource interface
    sl.registerLazySingleton<SeedSecretDatasource>(
      () => sl<FssSeedSecretDatasource>(),
    );

    // Seed secret store (repository pattern)
    sl.registerLazySingleton<SeedSecretStorePort>(
      () => SeedSecretStore(seedSecretDatasource: sl()),
    );

    // Legacy seed secret store (read-only for old format)
    sl.registerLazySingleton<LegacySeedSecretStorePort>(
      () => LegacySeedSecretStore(flutterSecureStorage: sl()),
    );

    // Seed usage repository (Drift/SQLite)
    sl.registerLazySingleton<SeedUsageRepositoryPort>(
      () => DriftSeedUsageRepository(database: sl()),
    );

    // Seed crypto operations (BIP32/BIP39)
    sl.registerLazySingleton<SeedCryptoPort>(() => Bip32And39SeedCrypto());

    // Mnemonic generator (BDK)
    sl.registerLazySingleton<MnemonicGeneratorPort>(
      () => BdkMnemonicGenerator(),
    );
  }

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    // Create and import
    sl.registerFactory<CreateNewSeedMnemonicUseCase>(
      () => CreateNewSeedMnemonicUseCase(
        mnemonicGenerator: sl(),
        seedCrypto: sl(),
        seedSecretStore: sl(),
        seedUsageRepository: sl(),
      ),
    );

    sl.registerFactory<ImportSeedMnemonicUseCase>(
      () => ImportSeedMnemonicUseCase(
        seedSecretStore: sl(),
        seedCrypto: sl(),
        seedUsageRepository: sl(),
      ),
    );

    sl.registerFactory<ImportSeedBytesUseCase>(
      () => ImportSeedBytesUseCase(
        seedSecretStore: sl(),
        seedCrypto: sl(),
        seedUsageRepository: sl(),
      ),
    );

    // Read
    sl.registerFactory<GetSeedSecretUseCase>(
      () => GetSeedSecretUseCase(seedSecretStore: sl()),
    );

    sl.registerFactory<LoadAllStoredSeedSecretsUseCase>(
      () => LoadAllStoredSeedSecretsUseCase(
        seedSecretStore: sl(),
        seedCrypto: sl(),
      ),
    );

    sl.registerFactory<LoadLegacySeedsUseCase>(
      () =>
          LoadLegacySeedsUseCase(legacySeedSecretStore: sl(), seedCrypto: sl()),
    );

    // Usage tracking
    sl.registerFactory<RegisterSeedUsageUseCase>(
      () => RegisterSeedUsageUseCase(seedUsageRepository: sl()),
    );

    sl.registerFactory<DeregisterSeedUsageUseCase>(
      () => DeregisterSeedUsageUseCase(seedUsageRepository: sl()),
    );

    sl.registerFactory<GetSeedUsageByConsumerUseCase>(
      () => GetSeedUsageByConsumerUseCase(seedUsageRepository: sl()),
    );

    sl.registerFactory<ListUsedSeedsUseCase>(
      () => ListUsedSeedsUseCase(seedUsageRepository: sl()),
    );

    // Composed use cases
    sl.registerFactory<DeregisterSeedUsageWithFingerprintCheckUseCase>(
      () => DeregisterSeedUsageWithFingerprintCheckUseCase(
        getSeedUsageByConsumer: sl(),
        deregisterSeedUsage: sl(),
      ),
    );

    // Delete
    sl.registerFactory<DeleteSeedUseCase>(
      () => DeleteSeedUseCase(seedSecretStore: sl(), seedUsageRepository: sl()),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {
    // Public facade for other features
    sl.registerLazySingleton<SeedsFacade>(
      () => SeedsFacade(
        createNewSeedMnemonicUseCase: sl(),
        importSeedMnemonicUseCase: sl(),
        getSeedSecretUseCase: sl(),
        registerSeedUsageUseCase: sl(),
        deregisterSeedUsageWithFingerprintCheck: sl(),
      ),
    );

    // Presentation bloc
    sl.registerFactory<SeedsViewBloc>(
      () => SeedsViewBloc(
        loadAllStoredSeedSecretsUseCase: sl(),
        listUsedSeedsUseCase: sl(),
        deleteSeedUsecase: sl(),
        loadLegacySeedsUseCase: sl(),
      ),
    );
  }
}
