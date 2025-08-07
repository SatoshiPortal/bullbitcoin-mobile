import 'package:bb_mobile/core/core_locator.dart';
import 'package:bb_mobile/features/address_view/address_view_locator.dart';
import 'package:bb_mobile/features/app_startup/app_startup_locator.dart';
import 'package:bb_mobile/features/app_unlock/app_unlock_locator.dart';
import 'package:bb_mobile/features/autoswap/autoswap_locator.dart';
import 'package:bb_mobile/features/backup_settings/backup_settings_locator.dart';
import 'package:bb_mobile/features/backup_wallet/backup_wallet_locator.dart';
import 'package:bb_mobile/features/bitcoin_price/bitcoin_price_locator.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/locator.dart';
import 'package:bb_mobile/features/buy/buy_locator.dart';
import 'package:bb_mobile/features/electrum_settings/electrum_settings_locator.dart';
import 'package:bb_mobile/features/exchange/exchange_locator.dart';
import 'package:bb_mobile/features/fund_exchange/fund_exchange_locator.dart';
import 'package:bb_mobile/features/import_mnemonic/locator.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_locator.dart';
import 'package:bb_mobile/features/key_server/key_server_locator.dart';
import 'package:bb_mobile/features/legacy_seed_view/legacy_seed_view_locator.dart';
import 'package:bb_mobile/features/onboarding/onboarding_locator.dart';
import 'package:bb_mobile/features/pin_code/pin_code_locator.dart';
import 'package:bb_mobile/features/receive/receive_locator.dart';
import 'package:bb_mobile/features/sell/sell_locator.dart';
import 'package:bb_mobile/features/send/send_locator.dart';
import 'package:bb_mobile/features/settings/settings_locator.dart';
import 'package:bb_mobile/features/swap/swap_locator.dart';
import 'package:bb_mobile/features/test_wallet_backup/test_wallet_backup_locator.dart';
import 'package:bb_mobile/features/transactions/transactions_locator.dart';
import 'package:bb_mobile/features/wallet/wallet_locator.dart';
import 'package:get_it/get_it.dart';

final GetIt locator = GetIt.instance;

class AppLocator {
  /// Call this in the `main` function **before** `runApp()`
  static Future<void> setup() async {
    locator.enableRegisteringMultipleInstancesOfOneType();

    // Register core dependencies first
    CoreLocator.register();
    await CoreLocator.registerDatasources();
    await CoreLocator.registerRepositories();
    CoreLocator.registerServices();
    CoreLocator.registerUsecases();

    // Register feature-specific dependencies
    KeyServerLocator.setup();
    ElectrumSettingsLocator.setup();
    PinCodeLocator.setup();
    AppStartupLocator.setup();
    AppUnlockLocator.setup();
    OnboardingLocator.setup();
    LegacySeedViewLocator.setup();
    SettingsLocator.setup();
    BitcoinPriceLocator.setup();
    WalletLocator.setup();
    TransactionsLocator.registerUsecases();
    TransactionsLocator.registerBlocs();
    ReceiveLocator.setup();
    SendLocator.setup();
    BackupSettingsLocator.setup();
    BackupWalletLocator.setup();
    TestWalletBackupLocator.setup();
    ImportWatchOnlyLocator.setup();
    BroadcastSignedTxLocator.setup();
    SwapLocator.setup();
    ExchangeLocator.setup();
    BuyLocator.setup();
    SellLocator.setup();
    FundExchangeLocator.setup();
    AutoSwapLocator.setup();
    AddressViewLocator.setup();
    ImportMnemonicLocator.setup();
  }
}
