import 'package:bb_mobile/core/bip85/bip85_locator.dart';
import 'package:bb_mobile/core/bitbox/bitbox_locator.dart';
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
    BlockchainLocator.registerDatasources();
    await ElectrumLocator.registerDatasources();
    ExchangeLocator.registerDatasources();
    FeesLocator.registerDatasources();
    await PayjoinLocator.registerDatasources();
    await RecoverbullLocator.registerDatasources();
    SeedLocator.registerDatasources();
    await StorageLocator.registerDatasources();
    await SwapsLocator.registerDatasources();
    await WalletLocator.registerDatasourceres();
    LabelsLocator.registerDatasources();
    await SettingsLocator.registerDatasources();
    await Bip85DerivationsLocator.registerDatasources();
    LedgerLocator.registerDatasources();
    BitBoxCoreLocator.registerDatasources();
  }

  static void registerPorts() {
    ElectrumLocator.registerPorts();
    BlockchainLocator.registerPorts();
    SwapsLocator.registerPorts();
    WalletLocator.registerPorts();
  }

  static Future<void> registerRepositories() async {
    await TorLocator.registerRepositories();
    BlockchainLocator.registerRepositories();
    ElectrumLocator.registerRepositories();
    ExchangeLocator.registerRepositories();
    FeesLocator.registerRepositories();
    LabelsLocator.registerRepositories();
    PayjoinLocator.registerRepositories();
    await RecoverbullLocator.registerRepositories();
    SeedLocator.registerRepositories();
    StorageLocator.registerRepositories();
    await SettingsLocator.registerRepositories();
    SwapsLocator.registerRepositories();
    WalletLocator.registerRepositories();
    await Bip85DerivationsLocator.registerRepositories();
    LedgerLocator.registerRepositories();
    BitBoxCoreLocator.registerRepositories();
  }

  static void registerServices() {
    SeedLocator.registerServices();
    SwapsLocator.registerServices();
  }

  static void registerUsecases() {
    ElectrumLocator.registerUsecases();
    BlockchainLocator.registerUsecases();
    ExchangeLocator.registerUseCases();
    FeesLocator.registerUseCases();
    LabelsLocator.registerUseCases();
    PayjoinLocator.registerUsecases();
    RecoverbullLocator.registerUsecases();
    SeedLocator.registerUsecases();
    StorageLocator.registerUsecases();
    SettingsLocator.registerUsecases();
    SwapsLocator.registerUsecases();
    TorLocator.registerUsecases();
    WalletLocator.registerUsecases();
    Bip85DerivationsLocator.registerUsecases();
    LedgerLocator.registerUsecases();
    BitBoxCoreLocator.registerUsecases();
  }
}
