import 'package:bb_mobile/core/bip85/bip85_locator.dart';
import 'package:bb_mobile/core/bitbox/bitbox_locator.dart';
import 'package:bb_mobile/core/blockchain/blockchain_locator.dart';
import 'package:bb_mobile/core/electrum/frameworks/di/electrum_locator.dart';
import 'package:bb_mobile/core/exchange/exchange_locator.dart';
import 'package:bb_mobile/core/fees/fees_locator.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/core/ledger/ledger_locator.dart';
import 'package:bb_mobile/core/mempool/mempool_locator.dart';
import 'package:bb_mobile/core/mesh/mesh_locator.dart';
import 'package:bb_mobile/core/payjoin/payjoin_locator.dart';
import 'package:bb_mobile/core/recoverbull/recoverbull_locator.dart';
import 'package:bb_mobile/core/seed/seed_locator.dart';
import 'package:bb_mobile/core/settings/settings_locator.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/storage_locator.dart';
import 'package:bb_mobile/core/swaps/swaps_locator.dart';
import 'package:bb_mobile/core/tor/tor_locator.dart';
import 'package:bb_mobile/core/wallet/wallet_locator.dart';
import 'package:get_it/get_it.dart';

class CoreLocator {
  static void register(GetIt locator, SqliteDatabase database) {
    locator.registerLazySingleton<SqliteDatabase>(() => database);
  }

  static Future<void> registerDatasources(GetIt locator) async {
    await TorLocator.registerDatasources(locator);
    BlockchainLocator.registerDatasources(locator);
    await ElectrumLocator.registerDatasources(locator);
    ExchangeLocator.registerDatasources(locator);
    FeesLocator.registerDatasources(locator);
    await MempoolLocator.registerDatasources(locator);
    PayjoinLocator.registerDatasources(locator);
    await RecoverbullLocator.registerDatasources(locator);
    await StorageLocator.registerDatasources(locator);
    SeedLocator.registerDatasources(locator);
    await SwapsLocator.registerDatasources(locator);
    await WalletLocator.registerDatasources(locator);
    await SettingsLocator.registerDatasources(locator);
    Bip85DerivationsLocator.registerDatasources(locator);
    LedgerLocator.registerDatasources(locator);
    BitBoxCoreLocator.registerDatasources(locator);
  }

  static void registerPorts(GetIt locator) {
    ElectrumLocator.registerPorts(locator);
    BlockchainLocator.registerPorts(locator);
    MempoolLocator.registerPorts(locator);
    SwapsLocator.registerPorts(locator);
    WalletLocator.registerPorts(locator);
    LabelsLocator.registerPorts(locator);
  }

  static Future<void> registerRepositories(GetIt locator) async {
    await TorLocator.registerRepositories(locator);
    BlockchainLocator.registerRepositories(locator);
    ElectrumLocator.registerRepositories(locator);
    ExchangeLocator.registerRepositories(locator);
    FeesLocator.registerRepositories(locator);
    MempoolLocator.registerRepositories(locator);
    PayjoinLocator.registerRepositories(locator);
    SeedLocator.registerRepositories(locator);
    StorageLocator.registerRepositories(locator);
    await SettingsLocator.registerRepositories(locator);
    await RecoverbullLocator.registerRepositories(locator);
    SwapsLocator.registerRepositories(locator);
    WalletLocator.registerRepositories(locator);
    Bip85DerivationsLocator.registerRepositories(locator);
    LedgerLocator.registerRepositories(locator);
    BitBoxCoreLocator.registerRepositories(locator);
  }

  static void registerServices(GetIt locator) {
    MempoolLocator.registerServices(locator);
    SeedLocator.registerServices(locator);
    MeshLocator.registerServices(locator);
    SwapsLocator.registerServices(locator);
  }

  static void registerUsecases(GetIt locator) {
    LabelsLocator.registerUseCases(locator);
    ElectrumLocator.registerUsecases(locator);
    BlockchainLocator.registerUsecases(locator);
    ExchangeLocator.registerUseCases(locator);
    FeesLocator.registerUseCases(locator);
    MempoolLocator.registerUsecases(locator);
    PayjoinLocator.registerUsecases(locator);
    RecoverbullLocator.registerUsecases(locator);
    SeedLocator.registerUsecases(locator);
    StorageLocator.registerUsecases(locator);
    SettingsLocator.registerUsecases(locator);
    SwapsLocator.registerUsecases(locator);
    TorLocator.registerUsecases(locator);
    WalletLocator.registerUsecases(locator);
    Bip85DerivationsLocator.registerUsecases(locator);
    LedgerLocator.registerUsecases(locator);
    BitBoxCoreLocator.registerUsecases(locator);
  }

  static void registerFacades(GetIt locator) {
    LabelsLocator.registerFacade(locator);
  }

  static void registerFrameworks(GetIt locator) {
    LabelsLocator.registerFrameworks(locator);
  }
}
