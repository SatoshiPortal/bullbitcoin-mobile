import 'package:bb_mobile/core/ark/locator.dart';
import 'package:bb_mobile/core/core_locator.dart';
import 'package:bb_mobile/core/status/status_locator.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/address_view/address_view_locator.dart';
import 'package:bb_mobile/features/all_seed_view/all_seed_view_locator.dart';
import 'package:bb_mobile/features/app_startup/app_startup_locator.dart';
import 'package:bb_mobile/features/app_unlock/app_unlock_locator.dart';
import 'package:bb_mobile/features/autoswap/autoswap_locator.dart';
import 'package:bb_mobile/features/backup_settings/backup_settings_locator.dart';
import 'package:bb_mobile/features/bip85_entropy/locator.dart';
import 'package:bb_mobile/features/bitbox/bitbox_locator.dart';
import 'package:bb_mobile/features/bitcoin_price/bitcoin_price_locator.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/locator.dart';
import 'package:bb_mobile/features/buy/buy_locator.dart';
import 'package:bb_mobile/features/dca/dca_locator.dart';
import 'package:bb_mobile/features/electrum_settings/electrum_settings_locator.dart';
import 'package:bb_mobile/features/exchange/exchange_locator.dart';
import 'package:bb_mobile/features/mempool_settings/mempool_settings_locator.dart';
import 'package:bb_mobile/features/fund_exchange/fund_exchange_locator.dart';
import 'package:bb_mobile/features/import_mnemonic/locator.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_locator.dart';
import 'package:bb_mobile/features/ledger/ledger_locator.dart';
import 'package:bb_mobile/features/legacy_seed_view/legacy_seed_view_locator.dart';
import 'package:bb_mobile/features/onboarding/onboarding_locator.dart';
import 'package:bb_mobile/features/pay/pay_locator.dart';
import 'package:bb_mobile/features/pin_code/pin_code_locator.dart';
import 'package:bb_mobile/features/receive/receive_locator.dart';
import 'package:bb_mobile/features/recipients/recipients_locator.dart';
import 'package:bb_mobile/features/replace_by_fee/locator.dart';
import 'package:bb_mobile/features/sell/sell_locator.dart';
import 'package:bb_mobile/features/send/send_locator.dart';
import 'package:bb_mobile/features/settings/settings_locator.dart';
import 'package:bb_mobile/features/status_check/locator.dart';
import 'package:bb_mobile/features/swap/swap_locator.dart';
import 'package:bb_mobile/features/test_wallet_backup/test_wallet_backup_locator.dart';
import 'package:bb_mobile/features/tor_settings/tor_settings_locator.dart';
import 'package:bb_mobile/features/transactions/transactions_locator.dart';
import 'package:bb_mobile/features/wallet/wallet_locator.dart';
import 'package:bb_mobile/features/withdraw/withdraw_locator.dart';
import 'package:get_it/get_it.dart';

final GetIt locator = GetIt.instance;

class AppLocator {
  /// Call this in the `main` function **before** `runApp()`
  static Future<void> setup(GetIt locator, SqliteDatabase database) async {
    locator.enableRegisteringMultipleInstancesOfOneType();

    // Register core dependencies first
    CoreLocator.register(locator, database);
    await CoreLocator.registerDatasources(locator);
    // Note: since the WalletLocator repositories depend on ports for electrum servers,
    // we need to make sure the ports are registered before the repositories
    // This is a hack though as normally repositories should not depend on ports
    // The proper solution is to refactor the code to remove this dependency
    CoreLocator.registerPorts(locator);
    await CoreLocator.registerRepositories(locator);
    CoreLocator.registerServices(locator);
    CoreLocator.registerUsecases(locator);
    CoreLocator.registerFrameworks(locator);
    CoreLocator.registerFacades(locator);

    // Register feature-specific dependencies
    ElectrumSettingsLocator.setup(locator);
    MempoolSettingsLocator.setup(locator);
    TorSettingsLocator.setup(locator);
    PinCodeLocator.setup(locator);
    AppStartupLocator.setup(locator);
    AppUnlockLocator.setup(locator);
    OnboardingLocator.setup(locator);
    LegacySeedViewLocator.setup(locator);
    AllSeedViewLocator.setup(locator);
    SettingsLocator.setup(locator);
    BitcoinPriceLocator.setup(locator);
    WalletLocator.setup(locator);
    TransactionsLocator.registerUsecases(locator);
    TransactionsLocator.registerBlocs(locator);
    ReceiveLocator.setup(locator);
    SendLocator.setup(locator);
    BackupSettingsLocator.setup(locator);
    TestWalletBackupLocator.setup(locator);
    ImportWatchOnlyLocator.setup(locator);
    BroadcastSignedTxLocator.setup(locator);
    SwapLocator.setup(locator);

    ExchangeLocator.setup(locator);
    BuyLocator.setup(locator);
    SellLocator.setup(locator);
    WithdrawLocator.setup(locator);
    PayLocator.setup(locator);
    StatusLocator.setup(locator);
    StatusCheckLocator.setup(locator);

    FundExchangeLocator.setup(locator);
    AutoSwapLocator.setup(locator);
    AddressViewLocator.setup(locator);
    ImportMnemonicLocator.setup(locator);
    DcaLocator.setup(locator);
    ReplaceByFeeLocator.setup(locator);
    Bip85EntropyLocator.setup(locator);
    LedgerLocator.setup(locator);
    RecipientsLocator.setup(locator);
    BitBoxLocator.setup(locator);
    ArkCoreLocator.setup(locator);
  }
}
