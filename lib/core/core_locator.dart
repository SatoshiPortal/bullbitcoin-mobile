import 'package:bb_mobile/core/bip85/bip85_locator.dart';
import 'package:bb_mobile/core/bitbox/bitbox_locator.dart';
import 'package:bb_mobile/core/blockchain/blockchain_locator.dart';
import 'package:bb_mobile/core/electrum/frameworks/di/electrum_locator.dart';
import 'package:bb_mobile/core/exchange/exchange_locator.dart';
import 'package:bb_mobile/core/fees/fees_locator.dart';
import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/labels/labels_locator.dart';
import 'package:bb_mobile/core/ledger/ledger_locator.dart';
import 'package:bb_mobile/core/mempool/mempool_locator.dart';
import 'package:bb_mobile/core/payjoin/payjoin_locator.dart';
import 'package:bb_mobile/core/recoverbull/recoverbull_locator.dart';
import 'package:bb_mobile/core/seed/seed_locator.dart';
import 'package:bb_mobile/core/settings/settings_locator.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/storage_locator.dart';
import 'package:bb_mobile/core/swaps/swaps_locator.dart';
import 'package:bb_mobile/core/tor/tor_locator.dart';
import 'package:bb_mobile/core/wallet/wallet_locator.dart';

class CoreLocator {
  static void register() {
    sl.registerLazySingleton<SqliteDatabase>(() => SqliteDatabase());
  }

  static Future<void> registerDatasources() async {
    LabelsLocator.registerDatasources(sl);
    await TorLocator.registerDatasources(sl);
    BlockchainLocator.registerDatasources(sl);
    await ElectrumLocator.registerDatasources(sl);
    ExchangeLocator.registerDatasources(sl);
    FeesLocator.registerDatasources(sl);
    await MempoolLocator.registerDatasources(sl);
    PayjoinLocator.registerDatasources(sl);
    await RecoverbullLocator.registerDatasources(sl);
    SeedLocator.registerDatasources(sl);
    await StorageLocator.registerDatasources(sl);
    await SwapsLocator.registerDatasources(sl);
    await WalletLocator.registerDatasources(sl);
    await SettingsLocator.registerDatasources(sl);
    Bip85DerivationsLocator.registerDatasources(sl);
    LedgerLocator.registerDatasources();
    BitBoxCoreLocator.registerDatasources();
  }

  static void registerPorts() {
    ElectrumLocator.registerPorts(sl);
    BlockchainLocator.registerPorts(sl);
    MempoolLocator.registerPorts(sl);
    SwapsLocator.registerPorts(sl);
    WalletLocator.registerPorts(sl);
  }

  static Future<void> registerRepositories() async {
    LabelsLocator.registerRepositories(sl);
    await TorLocator.registerRepositories(sl);
    BlockchainLocator.registerRepositories(sl);
    ElectrumLocator.registerRepositories(sl);
    ExchangeLocator.registerRepositories(sl);
    FeesLocator.registerRepositories(sl);
    MempoolLocator.registerRepositories(sl);
    PayjoinLocator.registerRepositories(sl);
    SeedLocator.registerRepositories(sl);
    StorageLocator.registerRepositories(sl);
    await SettingsLocator.registerRepositories(sl);
    await RecoverbullLocator.registerRepositories(sl);
    SwapsLocator.registerRepositories(sl);
    WalletLocator.registerRepositories(sl);
    Bip85DerivationsLocator.registerRepositories(sl);
    LedgerLocator.registerRepositories();
    BitBoxCoreLocator.registerRepositories();
  }

  static void registerServices() {
    MempoolLocator.registerServices(sl);
    SeedLocator.registerServices(sl);
    SwapsLocator.registerServices(sl);
  }

  static void registerUsecases() {
    LabelsLocator.registerUseCases(sl);
    ElectrumLocator.registerUsecases(sl);
    BlockchainLocator.registerUsecases(sl);
    ExchangeLocator.registerUseCases(sl);
    FeesLocator.registerUseCases(sl);
    MempoolLocator.registerUsecases(sl);
    PayjoinLocator.registerUsecases(sl);
    RecoverbullLocator.registerUsecases(sl);
    SeedLocator.registerUsecases(sl);
    StorageLocator.registerUsecases(sl);
    SettingsLocator.registerUsecases(sl);
    SwapsLocator.registerUsecases(sl);
    TorLocator.registerUsecases(sl);
    WalletLocator.registerUsecases(sl);
    Bip85DerivationsLocator.registerUsecases(sl);
    LedgerLocator.registerUsecases();
    BitBoxCoreLocator.registerUsecases();
  }
}
