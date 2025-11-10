import 'package:bb_mobile/core/ark/locator.dart';
import 'package:bb_mobile/core/bip85/bip85_locator.dart';
import 'package:bb_mobile/core/blockchain/blockchain_locator.dart';
import 'package:bb_mobile/core/electrum/frameworks/di/electrum_locator.dart';
import 'package:bb_mobile/core/exchange/exchange_locator.dart' as core;
import 'package:bb_mobile/core/fees/fees_locator.dart';
import 'package:bb_mobile/core/payjoin/payjoin_locator.dart';
import 'package:bb_mobile/core/recoverbull/recoverbull_locator.dart';
import 'package:bb_mobile/core/seed/seed_locator.dart';
import 'package:bb_mobile/core/settings/settings_locator.dart';
import 'package:bb_mobile/core/status/status_locator.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/storage_locator.dart';
import 'package:bb_mobile/core/swaps/swaps_locator.dart';
import 'package:bb_mobile/core/tor/tor_locator.dart';
import 'package:bb_mobile/core/wallet/wallet_locator.dart';
import 'package:bb_mobile/features/exchange/exchange_locator.dart' as features;
import 'package:bb_mobile/locator.dart';
import 'package:get_it/get_it.dart';

final GetIt backgroundLocator = GetIt.asNewInstance();

class BackgroundTasksLocator {
  static Future<void> setup() async {
    backgroundLocator.enableRegisteringMultipleInstancesOfOneType();

    registerDatabase();
    await registerDatasources();
    registerPorts();
    await registerRepositories();
    registerServices();
    registerUsecases();
    registerFeatures();
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
    await StorageLocator.registerDatasources(backgroundLocator);
    await SwapsLocator.registerDatasources(backgroundLocator);
    await WalletLocator.registerDatasources(backgroundLocator);
    await SettingsLocator.registerDatasources(backgroundLocator);
    FeesLocator.registerDatasources(backgroundLocator);
    SeedLocator.registerDatasources(backgroundLocator);
    core.ExchangeLocator.registerDatasources(backgroundLocator);
    PayjoinLocator.registerDatasources(backgroundLocator);
    await TorLocator.registerDatasources(backgroundLocator);
    await RecoverbullLocator.registerDatasources(backgroundLocator);
    Bip85DerivationsLocator.registerDatasources(backgroundLocator);
  }

  static void registerPorts() {
    ElectrumLocator.registerPorts(backgroundLocator);
    BlockchainLocator.registerPorts(backgroundLocator);
    SwapsLocator.registerPorts(backgroundLocator);
    WalletLocator.registerPorts(backgroundLocator);
  }

  static Future<void> registerRepositories() async {
    BlockchainLocator.registerRepositories(backgroundLocator);
    ElectrumLocator.registerRepositories(backgroundLocator);
    StorageLocator.registerRepositories(backgroundLocator);
    await SettingsLocator.registerRepositories(backgroundLocator);
    SwapsLocator.registerRepositories(backgroundLocator);
    WalletLocator.registerRepositories(backgroundLocator);
    FeesLocator.registerRepositories(backgroundLocator);
    SeedLocator.registerRepositories(backgroundLocator);
    core.ExchangeLocator.registerRepositories(backgroundLocator);
    PayjoinLocator.registerRepositories(backgroundLocator);
    await TorLocator.registerRepositories(backgroundLocator);
    await RecoverbullLocator.registerRepositories(backgroundLocator);
    Bip85DerivationsLocator.registerRepositories(backgroundLocator);
  }

  static void registerServices() {
    SwapsLocator.registerServices(backgroundLocator);
  }

  static void registerUsecases() {
    ElectrumLocator.registerUsecases(backgroundLocator);
    BlockchainLocator.registerUsecases(backgroundLocator);
    StorageLocator.registerUsecases(backgroundLocator);
    SettingsLocator.registerUsecases(backgroundLocator);
    SwapsLocator.registerUsecases(backgroundLocator);
    WalletLocator.registerUsecases(backgroundLocator);
    FeesLocator.registerUseCases(backgroundLocator);
    SeedLocator.registerUsecases(backgroundLocator);
    SeedLocator.registerServices(backgroundLocator);
    core.ExchangeLocator.registerUseCases(backgroundLocator);
    PayjoinLocator.registerUsecases(backgroundLocator);
    TorLocator.registerUsecases(backgroundLocator);
    RecoverbullLocator.registerUsecases(backgroundLocator);
    Bip85DerivationsLocator.registerUsecases(backgroundLocator);
  }

  static void registerFeatures() {
    features.ExchangeLocator.setup(backgroundLocator);
    ArkCoreLocator.setup(backgroundLocator);
    StatusLocator.setup(backgroundLocator);
  }
}
