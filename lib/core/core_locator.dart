import 'package:bb_mobile/core/bip85/bip85_locator.dart';
import 'package:bb_mobile/core/blockchain/blockchain_locator.dart';
import 'package:bb_mobile/core/electrum/frameworks/di/electrum_locator.dart';
import 'package:bb_mobile/core/exchange/exchange_locator.dart';
import 'package:bb_mobile/core/fees/fees_locator.dart';
import 'package:bb_mobile/core/labels/labels_locator.dart';
import 'package:bb_mobile/core/ledger/ledger_locator.dart';
import 'package:bb_mobile/core/payjoin/payjoin_locator.dart';
import 'package:bb_mobile/core/recoverbull/recoverbull_locator.dart';
import 'package:bb_mobile/core/seed/seed_locator.dart';
import 'package:bb_mobile/core/settings/settings_locator.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/storage_locator.dart';
import 'package:bb_mobile/core/swaps/swaps_locator.dart';
import 'package:bb_mobile/core/tor/tor_locator.dart';
import 'package:bb_mobile/core/wallet/wallet_locator.dart';
import 'package:bb_mobile/locator.dart';

class CoreLocator {
  static void register() {
    locator.registerLazySingleton<SqliteDatabase>(() => SqliteDatabase());
  }

  static Future<void> registerDatasources() async {
    await TorLocator.registerDatasources(locator);
    BlockchainLocator.registerDatasources(locator);
    await ElectrumLocator.registerDatasources(locator);
    ExchangeLocator.registerDatasources(locator);
    FeesLocator.registerDatasources(locator);
    PayjoinLocator.registerDatasources(locator);
    await RecoverbullLocator.registerDatasources(locator);
    SeedLocator.registerDatasources(locator);
    await StorageLocator.registerDatasources(locator);
    await SwapsLocator.registerDatasources(locator);
    await WalletLocator.registerDatasources(locator);
    LabelsLocator.registerDatasources();
    await SettingsLocator.registerDatasources(locator);
    Bip85DerivationsLocator.registerDatasources(locator);
    LedgerLocator.registerDatasources();
  }

  static void registerPorts() {
    ElectrumLocator.registerPorts(locator);
    BlockchainLocator.registerPorts(locator);
    SwapsLocator.registerPorts(locator);
    WalletLocator.registerPorts(locator);
  }

  static Future<void> registerRepositories() async {
    await TorLocator.registerRepositories(locator);
    BlockchainLocator.registerRepositories(locator);
    ElectrumLocator.registerRepositories(locator);
    ExchangeLocator.registerRepositories(locator);
    FeesLocator.registerRepositories(locator);
    LabelsLocator.registerRepositories();
    PayjoinLocator.registerRepositories(locator);
    await RecoverbullLocator.registerRepositories(locator);
    SeedLocator.registerRepositories(locator);
    StorageLocator.registerRepositories(locator);
    await SettingsLocator.registerRepositories(locator);
    SwapsLocator.registerRepositories(locator);
    WalletLocator.registerRepositories(locator);
    Bip85DerivationsLocator.registerRepositories(locator);
    LedgerLocator.registerRepositories();
  }

  static void registerServices() {
    SeedLocator.registerServices(locator);
    SwapsLocator.registerServices(locator);
  }

  static void registerUsecases() {
    ElectrumLocator.registerUsecases(locator);
    BlockchainLocator.registerUsecases(locator);
    ExchangeLocator.registerUseCases(locator);
    FeesLocator.registerUseCases(locator);
    LabelsLocator.registerUseCases();
    PayjoinLocator.registerUsecases(locator);
    RecoverbullLocator.registerUsecases(locator);
    SeedLocator.registerUsecases(locator);
    StorageLocator.registerUsecases(locator);
    SettingsLocator.registerUsecases(locator);
    SwapsLocator.registerUsecases(locator);
    TorLocator.registerUsecases(locator);
    WalletLocator.registerUsecases(locator);
    Bip85DerivationsLocator.registerUsecases(locator);
    LedgerLocator.registerUsecases();
  }
}
