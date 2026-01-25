import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/secrets/application/ports/legacy_seed_secret_store_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/mnemonic_generator_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_crypto_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/usecases/create_new_mnemonic_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/delete_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/deregister_secret_usage_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/deregister_secret_usages_of_consumer_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/get_secret_usages_by_consumer_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/get_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/import_mnemonic_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/import_seed_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/list_used_secrets_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/load_all_stored_secrets_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/load_legacy_secrets_usecase.dart';
import 'package:bb_mobile/features/secrets/frameworks/secure_storage/fss_secret_datasource.dart';
import 'package:bb_mobile/features/secrets/interface_adapters/bdk_mnemonic_generator.dart';
import 'package:bb_mobile/features/secrets/interface_adapters/bip32_and_39_seed_crypto.dart';
import 'package:bb_mobile/features/secrets/interface_adapters/legacy_seed_secret_store.dart';
import 'package:bb_mobile/features/secrets/interface_adapters/secret_usage/drift_secret_usage_repository.dart';
import 'package:bb_mobile/features/secrets/interface_adapters/secrets/secret_datasource.dart';
import 'package:bb_mobile/features/secrets/interface_adapters/secrets/secret_store.dart';
import 'package:bb_mobile/features/secrets/presentation/blocs/secrets_view_bloc.dart';
import 'package:bb_mobile/features/secrets/public/secrets_facade.dart';

class SecretsDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {
    // Seed secret datasource (Flutter Secure Storage)
    sl.registerLazySingleton<FssSecretDatasource>(
      () => FssSecretDatasource(flutterSecureStorage: sl()),
    );
  }

  @override
  Future<void> registerDrivenAdapters() async {
    // Seed secret datasource interface
    sl.registerLazySingleton<SecretDatasource>(() => sl<FssSecretDatasource>());

    // Seed crypto operations (BIP32/BIP39)
    sl.registerLazySingleton<SecretCryptoPort>(() => Bip32And39SecretCrypto());

    // Seed secret store (repository pattern)
    sl.registerLazySingleton<SecretStorePort>(
      () => SecretStore(secretDatasource: sl()),
    );

    // Legacy seed secret store (read-only for old format)
    sl.registerLazySingleton<LegacySecretStorePort>(
      () => LegacySecretStore(flutterSecureStorage: sl(), secretCrypto: sl()),
    );

    // Seed usage repository (Drift/SQLite)
    sl.registerLazySingleton<SecretUsageRepositoryPort>(
      () => DriftSecretUsageRepository(database: sl()),
    );

    // Mnemonic generator (BDK)
    sl.registerLazySingleton<MnemonicGeneratorPort>(
      () => BdkMnemonicGenerator(),
    );
  }

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    sl.registerFactory<CreateNewMnemonicSecretUseCase>(
      () => CreateNewMnemonicSecretUseCase(
        mnemonicGenerator: sl(),
        secretCrypto: sl(),
        secretStore: sl(),
        secretUsageRepository: sl(),
      ),
    );

    sl.registerFactory<DeleteSecretUseCase>(
      () => DeleteSecretUseCase(secretStore: sl(), secretUsageRepository: sl()),
    );

    sl.registerFactory<DeregisterSecretUsageUseCase>(
      () => DeregisterSecretUsageUseCase(secretUsageRepository: sl()),
    );

    sl.registerFactory<DeregisterSecretUsagesOfConsumerUseCase>(
      () =>
          DeregisterSecretUsagesOfConsumerUseCase(secretUsageRepository: sl()),
    );

    sl.registerFactory<GetSecretUsagesByConsumerUseCase>(
      () => GetSecretUsagesByConsumerUseCase(secretUsageRepository: sl()),
    );

    sl.registerFactory<GetSecretUseCase>(
      () => GetSecretUseCase(secretStore: sl()),
    );

    sl.registerFactory<ImportMnemonicSecretUseCase>(
      () => ImportMnemonicSecretUseCase(
        secretStore: sl(),
        secretCrypto: sl(),
        secretUsageRepository: sl(),
      ),
    );

    sl.registerFactory<ImportSeedSecretUseCase>(
      () => ImportSeedSecretUseCase(
        secretStore: sl(),
        secretCrypto: sl(),
        secretUsageRepository: sl(),
      ),
    );

    sl.registerFactory<ListUsedSecretsUseCase>(
      () => ListUsedSecretsUseCase(secretUsageRepository: sl()),
    );

    sl.registerFactory<LoadAllStoredSecretsUseCase>(
      () => LoadAllStoredSecretsUseCase(secretStore: sl()),
    );

    sl.registerFactory<LoadLegacySecretsUseCase>(
      () => LoadLegacySecretsUseCase(legacySecretStore: sl()),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {
    // Public facade for other features
    sl.registerLazySingleton<SecretsFacade>(
      () => SecretsFacade(
        createNewSecretMnemonicUseCase: sl(),
        importSecretMnemonicUseCase: sl(),
        getSecretUseCase: sl(),
        getSecretUsagesByConsumerUseCase: sl(),
        deregisterSecretUsageUseCase: sl(),
        deregisterSecretUsagesOfConsumerUseCase: sl(),
      ),
    );

    // Presentation bloc
    sl.registerFactory<SecretsViewBloc>(
      () => SecretsViewBloc(
        loadAllStoredSecretsUseCase: sl(),
        listUsedSecretsUseCase: sl(),
        deleteSecretUsecase: sl(),
        loadLegacySecretsUseCase: sl(),
      ),
    );
  }
}
