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
    await TorLocator.registerDatasources();
    BlockchainLocator.registerDatasources(locator);
    await ElectrumLocator.registerDatasources(locator);
    ExchangeLocator.registerDatasources();
    FeesLocator.registerDatasources(locator);
    await PayjoinLocator.registerDatasources();
    await RecoverbullLocator.registerDatasources();
    SeedLocator.registerDatasources();
    await StorageLocator.registerDatasources(locator);
    await SwapsLocator.registerDatasources(locator);
    await WalletLocator.registerDatasources(locator);
    LabelsLocator.registerDatasources();
    await SettingsLocator.registerDatasources(locator);
    await Bip85DerivationsLocator.registerDatasources();
    LedgerLocator.registerDatasources();
  }

  static void registerPorts() {
    ElectrumLocator.registerPorts(locator);
    BlockchainLocator.registerPorts(locator);
    SwapsLocator.registerPorts(locator);
    WalletLocator.registerPorts(locator);
  }

  static Future<void> registerRepositories() async {
    await TorLocator.registerRepositories();
    BlockchainLocator.registerRepositories(locator);
    ElectrumLocator.registerRepositories(locator);
    ExchangeLocator.registerRepositories();
    FeesLocator.registerRepositories(locator);
    LabelsLocator.registerRepositories();
    PayjoinLocator.registerRepositories();
    await RecoverbullLocator.registerRepositories();
    SeedLocator.registerRepositories();
    StorageLocator.registerRepositories(locator);
    await SettingsLocator.registerRepositories(locator);
    SwapsLocator.registerRepositories(locator);
    WalletLocator.registerRepositories(locator);
    await Bip85DerivationsLocator.registerRepositories();
    LedgerLocator.registerRepositories();
  }

  static void registerServices() {
    SeedLocator.registerServices();
    SwapsLocator.registerServices(locator);
  }

  static void registerUsecases() {
    ElectrumLocator.registerUsecases(locator);
    BlockchainLocator.registerUsecases(locator);
    ExchangeLocator.registerUseCases();
    FeesLocator.registerUseCases(locator);
    LabelsLocator.registerUseCases();
    PayjoinLocator.registerUsecases();
    RecoverbullLocator.registerUsecases();
    SeedLocator.registerUsecases();
    StorageLocator.registerUsecases(locator);
    SettingsLocator.registerUsecases(locator);
    SwapsLocator.registerUsecases(locator);
    TorLocator.registerUsecases();
    WalletLocator.registerUsecases(locator);
    Bip85DerivationsLocator.registerUsecases();
    LedgerLocator.registerUsecases();
  }
}
