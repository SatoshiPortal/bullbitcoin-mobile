import 'package:bb_mobile/background_setup.dart';
import 'package:bb_mobile/core/core_locator.dart';
import 'package:bb_mobile/core/status/status_locator.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/features/transactions/public/transactions_facade.dart';
import 'package:bb_mobile/features/address_view/address_view_locator.dart';
import 'package:bb_mobile/features/all_seed_view/all_seed_view_locator.dart';
import 'package:bb_mobile/features/app_startup/app_startup_locator.dart';
import 'package:bb_mobile/features/announcements/announcements_locator.dart';
import 'package:bb_mobile/features/app_unlock/app_unlock_locator.dart';
import 'package:bb_mobile/features/autoswap/autoswap_locator.dart';
import 'package:bb_mobile/features/autoswap/autoswap_watcher.dart';
import 'package:bb_mobile/features/autobuy/public/autobuy_facade.dart';
import 'package:bb_mobile/features/backup_settings/backup_settings_locator.dart';
import 'package:bb_mobile/features/bip85_entropy/locator.dart';
import 'package:bb_mobile/features/bitbox/bitbox_locator.dart';
import 'package:bb_mobile/features/bitcoin_price/bitcoin_price_locator.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/locator.dart';
import 'package:bb_mobile/features/buy/buy_locator.dart';
import 'package:bb_mobile/features/coins/coins_locator.dart';
import 'package:bb_mobile/features/consolidation/consolidation_locator.dart';
import 'package:bb_mobile/features/dca/dca_locator.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:bb_mobile/features/limit_orders/public/limit_orders_facade.dart';
import 'package:bb_mobile/features/electrum_settings/electrum_settings_locator.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/exchange_settings/public/exchange_settings_facade.dart';
import 'package:bb_mobile/features/exchange_support_chat/public/exchange_support_chat_facade.dart';
import 'package:bb_mobile/features/mempool_settings/mempool_settings_locator.dart';
import 'package:bb_mobile/features/fund_exchange/fund_exchange_locator.dart';
import 'package:bb_mobile/features/import_mnemonic/locator.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_locator.dart';
import 'package:bb_mobile/features/ledger/ledger_locator.dart';
import 'package:bb_mobile/features/onboarding/onboarding_locator.dart';
import 'package:bb_mobile/features/pay/pay_locator.dart';
import 'package:bb_mobile/features/pin_code/pin_code_locator.dart';
import 'package:bb_mobile/features/psbt_flow/psbt_flow_locator.dart';
import 'package:bb_mobile/features/receive/receive_locator.dart';
import 'package:bb_mobile/features/recipients/recipients_locator.dart';
import 'package:bb_mobile/features/replace_by_fee/locator.dart';
import 'package:bb_mobile/features/sell/sell_locator.dart';
import 'package:bb_mobile/features/send/send_locator.dart';
import 'package:bb_mobile/features/settings/settings_locator.dart';
import 'package:bb_mobile/features/sp/sp_locator.dart';
import 'package:bb_mobile/features/status_check/locator.dart';
import 'package:bb_mobile/features/swap/order_swap_watcher.dart';
import 'package:bb_mobile/features/swap/swap_locator.dart';
import 'package:bb_mobile/features/test_wallet_backup/test_wallet_backup_locator.dart';
import 'package:bb_mobile/features/tor_settings/tor_settings_locator.dart';
import 'package:bb_mobile/features/transactions/transactions_locator.dart';
import 'package:bb_mobile/features/wallet/wallet_locator.dart';
import 'package:bb_mobile/features/withdraw/withdraw_locator.dart';
import 'package:bb_mobile/features/wizard/wizard_locator.dart';
import 'package:get_it/get_it.dart';
import 'package:bull_logs/bull_logs.dart';

final GetIt locator = GetIt.instance;

class AppLocator {
  /// Call this in the `main` function **before** `runApp()`
  static Future<void> setup(
    GetIt locator,
    SqliteDatabase database, {
    required String payjoinDatabasePath,
    bool startPayjoinRecovery = true,
    bool startOrderSwapWatcher = true,
    bool startAutoswapWatcher = true,
  }) async {
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
    PayjoinSetup.setup(
      locator,
      database,
      payjoinDatabasePath,
      startRecovery: startPayjoinRecovery,
    );

    SyncLocator.setupForeground(locator);

    // Register feature-specific dependencies
    ElectrumSettingsLocator.setup(locator);
    MempoolSettingsLocator.setup(locator);
    TorSettingsLocator.setup(locator);
    PinCodeLocator.setup(locator);
    WizardLocator.setup(locator);
    AppStartupLocator.setup(locator);
    AppUnlockLocator.setup(locator);
    OnboardingLocator.setup(locator);
    AllSeedViewLocator.setup(locator);
    // SP starts watchers eagerly, so its wallet infrastructure must exist.
    // Wallet's SP use cases resolve the facade lazily, after registration.
    WalletLocator.setup(locator);
    SpLocator.setup(locator, startForegroundWatchers: true);
    SettingsLocator.setup(locator);
    setupBackgroundPreferences(
      locator,
      configureBackgroundTasks,
      notificationChannelId: paymentNotificationChannelId,
    );
    const LogsFeature().setup(locator);
    BitcoinPriceLocator.setup(locator);
    TransactionsLocator.registerAdapters(locator);
    TransactionsLocator.registerUsecases(locator);
    TransactionsLocator.registerBlocs(locator);
    ReceiveLocator.setup(locator);
    SendLocator.setup(locator);
    CoinsLocator.setup(locator);
    ConsolidationLocator.setup(locator);
    BackupSettingsLocator.setup(locator);
    TestWalletBackupLocator.setup(locator);
    ImportWatchOnlyLocator.setup(locator);
    BroadcastSignedTxLocator.setup(locator);
    PsbtFlowLocator.setup(locator);
    SwapLocator.setup(locator);
    AutoSwapLocator.setup(locator);
    AnnouncementsLocator.setup(locator);
    // Lifecycle side effect lives in the composition root, not in DI
    // registration: the background handler opts out via
    // [startOrderSwapWatcher] so polling only runs in the foreground app.
    if (startOrderSwapWatcher) {
      locator<OrderSwapWatcher>().start();
    }
    if (startAutoswapWatcher) {
      locator<AutoswapWatcher>().start();
    }

    ExchangeLocator.setup(locator);
    DefaultWalletsLocator.setup(locator);
    AutoBuyLocator.setup(locator);
    LimitOrdersLocator.setup(locator);
    ExchangeSettingsLocator.setup(locator);
    ExchangeSupportChatLocator.setup(locator);
    BuyLocator.setup(locator);
    SellLocator.setup(locator);
    WithdrawLocator.setup(locator);
    PayLocator.setup(locator);
    StatusLocator.setup(locator);
    StatusCheckLocator.setup(locator);

    FundExchangeLocator.setup(locator);
    AddressViewLocator.setup(locator);
    ImportMnemonicLocator.setup(locator);
    DcaLocator.setup(locator);
    ReplaceByFeeLocator.setup(locator);
    Bip85EntropyLocator.setup(locator);
    LedgerLocator.setup(locator);
    RecipientsLocator.setup(locator);
    BitBoxLocator.setup(locator);
  }
}
