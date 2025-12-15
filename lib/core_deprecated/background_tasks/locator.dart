import 'package:bb_mobile/core_deprecated/ark/locator.dart';
import 'package:bb_mobile/core_deprecated/bip85/bip85_locator.dart';
import 'package:bb_mobile/core_deprecated/blockchain/blockchain_locator.dart';
import 'package:bb_mobile/core_deprecated/electrum/frameworks/di/electrum_locator.dart';
import 'package:bb_mobile/core_deprecated/exchange/exchange_locator.dart'
    as core;
import 'package:bb_mobile/core_deprecated/fees/fees_locator.dart';
import 'package:bb_mobile/core_deprecated/payjoin/payjoin_locator.dart';
import 'package:bb_mobile/core_deprecated/recoverbull/recoverbull_locator.dart';
import 'package:bb_mobile/core_deprecated/seed/seed_locator.dart';
import 'package:bb_mobile/core_deprecated/settings/settings_locator.dart';
import 'package:bb_mobile/core_deprecated/status/status_locator.dart';
import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:bb_mobile/core_deprecated/storage/storage_locator.dart';
import 'package:bb_mobile/core_deprecated/swaps/swaps_locator.dart';
import 'package:bb_mobile/core_deprecated/tor/tor_locator.dart';
import 'package:bb_mobile/core_deprecated/wallet/wallet_locator.dart';
import 'package:bb_mobile/features/exchange/exchange_locator.dart' as features;
import 'package:get_it/get_it.dart';

class TaskLocator {
  static Future<void> setup(
    GetIt backgroundLocator,
    SqliteDatabase sqlite,
  ) async {
    backgroundLocator.enableRegisteringMultipleInstancesOfOneType();

    registerDatabase(backgroundLocator, sqlite);
    await registerDatasources(backgroundLocator);
    registerPorts(backgroundLocator);
    await registerRepositories(backgroundLocator);
    registerServices(backgroundLocator);
    registerUsecases(backgroundLocator);
    registerFeatures(backgroundLocator);
  }

  static void registerDatabase(GetIt backgroundLocator, SqliteDatabase sqlite) {
    backgroundLocator.registerLazySingleton<SqliteDatabase>(() => sqlite);
  }

  static Future<void> registerDatasources(GetIt backgroundLocator) async {
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

  static void registerPorts(GetIt backgroundLocator) {
    ElectrumLocator.registerPorts(backgroundLocator);
    BlockchainLocator.registerPorts(backgroundLocator);
    SwapsLocator.registerPorts(backgroundLocator);
    WalletLocator.registerPorts(backgroundLocator);
  }

  static Future<void> registerRepositories(GetIt backgroundLocator) async {
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

  static void registerServices(GetIt backgroundLocator) {
    SwapsLocator.registerServices(backgroundLocator);
  }

  static void registerUsecases(GetIt backgroundLocator) {
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

  static void registerFeatures(GetIt backgroundLocator) {
    features.ExchangeLocator.setup(backgroundLocator);
    ArkCoreLocator.setup(backgroundLocator);
    StatusLocator.setup(backgroundLocator);
  }
}
