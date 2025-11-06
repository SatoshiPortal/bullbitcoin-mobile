import 'package:bb_mobile/core/blockchain/blockchain_locator.dart';
import 'package:bb_mobile/core/electrum/frameworks/di/electrum_locator.dart';
import 'package:bb_mobile/core/settings/settings_locator.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/wallet_locator.dart';
import 'package:bb_mobile/locator.dart';
import 'package:get_it/get_it.dart';

final GetIt backgroundLocator = GetIt.asNewInstance();

class BackgroundTasksLocator {
  /// Call this in the `main` function **before** `runApp()`
  static Future<void> setup() async {
    backgroundLocator.enableRegisteringMultipleInstancesOfOneType();

    // Register core dependencies first
    registerDatabase();
    await registerDatasources();
    registerPorts();
    await registerRepositories();
    // registerServices();
    registerUsecases();
  }

  static void registerDatabase() {
    if (locator.isRegistered<SqliteDatabase>()) {
      backgroundLocator.registerLazySingleton<SqliteDatabase>(
        () => locator<SqliteDatabase>(),
      );
    } else {
      backgroundLocator.registerLazySingleton<SqliteDatabase>(
        () => SqliteDatabase(),
      );
    }
  }

  static Future<void> registerDatasources() async {
    BlockchainLocator.registerDatasources(backgroundLocator);
    await ElectrumLocator.registerDatasources(backgroundLocator);
    // SeedLocator.registerDatasources();
    // await StorageLocator.registerDatasources();
    // await SwapsLocator.registerDatasources();
    await WalletLocator.registerDatasources(backgroundLocator);
    await SettingsLocator.registerDatasources(backgroundLocator);
  }

  static void registerPorts() {
    // ElectrumLocator.registerPorts();
    // BlockchainLocator.registerPorts();
    // SwapsLocator.registerPorts();
    WalletLocator.registerPorts(backgroundLocator);
  }

  static Future<void> registerRepositories() async {
    BlockchainLocator.registerRepositories(backgroundLocator);
    ElectrumLocator.registerRepositories(backgroundLocator);

    // SeedLocator.registerRepositories();
    // StorageLocator.registerRepositories();
    await SettingsLocator.registerRepositories(backgroundLocator);
    // SwapsLocator.registerRepositories();
    WalletLocator.registerRepositories(backgroundLocator);
  }

  // static void registerServices() {
  //   SeedLocator.registerServices();
  //   SwapsLocator.registerServices();
  // }

  static void registerUsecases() {
    ElectrumLocator.registerUsecases(backgroundLocator);
    // BlockchainLocator.registerUsecases();

    // SeedLocator.registerUsecases();
    // StorageLocator.registerUsecases();
    // SettingsLocator.registerUsecases();
    // SwapsLocator.registerUsecases();
    WalletLocator.registerUsecases(backgroundLocator);
  }
}
