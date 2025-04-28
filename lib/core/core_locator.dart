import 'package:bb_mobile/core/blockchain/blockchain_locator.dart';
import 'package:bb_mobile/core/electrum/electrum_locator.dart';
import 'package:bb_mobile/core/exchange/exchange_locator.dart';
import 'package:bb_mobile/core/fees/fees_locator.dart';
import 'package:bb_mobile/core/labels/labels_locator.dart';
import 'package:bb_mobile/core/payjoin/payjoin_locator.dart';
import 'package:bb_mobile/core/recoverbull/recoverbull_locator.dart';
import 'package:bb_mobile/core/seed/seed_locator.dart';
import 'package:bb_mobile/core/settings/settings_locator.dart';
import 'package:bb_mobile/core/storage/storage_locator.dart';
import 'package:bb_mobile/core/swaps/swaps_locator.dart';
import 'package:bb_mobile/core/tor/tor_locator.dart';
import 'package:bb_mobile/core/wallet/wallet_locator.dart';

class CoreLocator {
  static Future<void> registerDatasources() async {
    await TorLocator.registerDatasources();
    BlockchainLocator.registerDatasources();
    await ElectrumLocator.registerDatasources();
    ExchangeLocator.registerDatasources();
    FeesLocator.registerDatasources();
    await LabelsLocator.registerDatasources();
    await PayjoinLocator.registerDatasources();
    await RecoverbullLocator.registerDatasources();
    SeedLocator.registerDatasources();
    StorageLocator.registerDatasourcer();
    await SwapsLocator.registerDatasources();
    await WalletLocator.registerDatasourceres();
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
    await SettingsLocator.registerRepositories();
    ElectrumLocator.registerUsecases();
    SwapsLocator.registerRepositories();
    WalletLocator.registerRepositories();
  }

  static void registerServices() {
    PayjoinLocator.registerServices();
    SeedLocator.registerServices();
    SwapsLocator.registerServices();
  }

  static void registerUsecases() {
    BlockchainLocator.registerUsecases();
    ExchangeLocator.registerUseCases();
    FeesLocator.registerUseCases();
    LabelsLocator.registerUseCases();
    PayjoinLocator.registerUsecases();
    RecoverbullLocator.registerUsecases();
    SeedLocator.registerUsecases();
    SettingsLocator.registerUsecases();
    SwapsLocator.registerUsecases();
    TorLocator.registerUsecases();
    WalletLocator.registerUsecases();
  }
}
