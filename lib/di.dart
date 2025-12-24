import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/address_view/address_view_di_module.dart';
import 'package:bb_mobile/features/all_seed_view/all_seed_view_di_module.dart';
import 'package:bb_mobile/features/app_startup/app_startup_di_module.dart';
import 'package:bb_mobile/features/app_unlock/app_unlock_di_module.dart';
import 'package:bb_mobile/features/autoswap/autoswap_di_module.dart';
import 'package:bb_mobile/features/backup_settings/backup_settings_di_module.dart';
import 'package:bb_mobile/features/bip85_entropy/bip85_entropy_di_module.dart';
import 'package:bb_mobile/features/bitbox/bitbox_di_module.dart';
import 'package:bb_mobile/features/bitcoin_price/bitcoin_price_di_module.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/broadcast_signed_tx_di_module.dart';
import 'package:bb_mobile/features/buy/buy_di_module.dart';
import 'package:bb_mobile/features/dca/dca_di_module.dart';
import 'package:bb_mobile/features/electrum_settings/electrum_settings_di_module.dart';
import 'package:bb_mobile/features/exchange/exchange_di_module.dart';
import 'package:bb_mobile/features/fund_exchange/fund_exchange_di_module.dart';
import 'package:bb_mobile/features/import_mnemonic/import_mnemonic_di_module.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_wallet_di_module.dart';
import 'package:bb_mobile/features/ledger/ledger_di_module.dart';
import 'package:bb_mobile/features/legacy_seed_view/legacy_seed_view_di_module.dart';
import 'package:bb_mobile/features/mempool_settings/mempool_settings_di_module.dart';
import 'package:bb_mobile/features/onboarding/onboarding_di_module.dart';
import 'package:bb_mobile/features/pay/pay_di_module.dart';
import 'package:bb_mobile/features/pin_code/pin_code_di_module.dart';
import 'package:bb_mobile/features/receive/receive_di_module.dart';
import 'package:bb_mobile/features/recipients/recipients_di_module.dart';
import 'package:bb_mobile/features/replace_by_fee/replace_by_fee_di_module.dart';
import 'package:bb_mobile/features/sell/sell_di_module.dart';
import 'package:bb_mobile/features/send/send_di_module.dart';
import 'package:bb_mobile/features/settings/settings_di_module.dart';
import 'package:bb_mobile/features/status_check/status_check_di_module.dart';
import 'package:bb_mobile/features/swap/swap_di_module.dart';
import 'package:bb_mobile/features/test_wallet_backup/test_wallet_backup_di_module.dart';
import 'package:bb_mobile/features/tor_settings/tor_settings_di_module.dart';
import 'package:bb_mobile/features/transactions/transactions_di_module.dart';
import 'package:bb_mobile/features/wallet/wallet_di_module.dart';
import 'package:bb_mobile/features/withdraw/withdraw_di_module.dart';

Future<void> initializeDependencies() async {
  sl.enableRegisteringMultipleInstancesOfOneType();

  // Register core dependencies first. Features can depend on core,
  // but core should not depend on features.
  await registerCoreDependencies();

  // Register feature-specific dependencies.
  // If a feature depends on another feature, ensure that the dependent feature
  // is registered first and that there are no circular dependencies between them
  // or with other features.
  // Ideally features should be as independent as possible,
  // communicating only via well-defined, strict interfaces (facades) if necessary.
  final featureModules = <FeatureDiModule>[
    AddressViewDiModule(), // Depends on core wallet
    AllSeedViewDiModule(), // Depends on core seed, core wallet
    AppStartupDiModule(), // Depends on core settings, core wallet, core seed, app_unlock, core storage, test_wallet_backup, pin_code, core tor
    AppUnlockDiModule(), // Depends on core storage, pin_code
    AutoSwapDiModule(), // Depends on core swaps, core settings, core wallet
    BackupSettingsDiModule(), // Depends on core wallet, core settings
    Bip85EntropyDiModule(), // Depends on core bip85, core seed
    BitBoxDiModule(), // Depends on core bitbox
    BitcoinPriceDiModule(), // Depends on core exchange, core settings
    BroadcastSignedTxDiModule(), // Depends on core blockchain
    BuyDiModule(), // Depends on core wallet, core exchange, core fees
    DcaDiModule(), // Depends on core exchange, core settings, core wallet
    ElectrumSettingsDiModule(), // Depends on core electrum
    ExchangeDiModule(), // Depends on core exchange
    FundExchangeDiModule(), // Depends on core exchange
    ImportMnemonicDiModule(), // Depends on core wallet
    ImportWatchOnlyWalletDiModule(), // Depends on core wallet
    LedgerDiModule(), // Depends on core ledger
    LegacySeedViewDiModule(), // Depends on core storage
    MempoolSettingsDiModule(), // Depends on core mempool
    OnboardingDiModule(), // Depends on core wallet
    PayDiModule(), // Depends on core exchange, core blockchain, core fees, core wallet, send, recipients
    PinCodeDiModule(), // Depends on core storage; TODO: check what can be moved to core (since the pin code repository is needed both in settings as in app unlock)
    ReceiveDiModule(), // Depends on core wallet, core swaps, core seed, core exchange, core payjoin, core labels
    RecipientsDiModule(), // Depends on core settings; TODO: frameworks should be moved to core (FlutterSecureStorage, BullbitcoinApiKeyProvider, Dio instances)
    ReplaceByFeeDiModule(), // Depends on core wallet
    SellDiModule(), // Depends on core exchange, core blockchain, core fees, core wallet, core labels, send
    SendDiModule(), // Depends on core wallet, core swaps, core seed, core blockchain, core fees, core payjoin, core exchange
    SettingsDiModule(), // Depends on core settings, core storage, core ark
    StatusCheckDiModule(), // Depends on core status, core wallet
    SwapDiModule(), // Depends on core swaps, core wallet, core seed, core blockchain, core fees, send; NOTE: many use cases might be duplicates from send
    TestWalletBackupDiModule(), // Depends on core wallet, core seed, core settings
    TorSettingsDiModule(), // Depends on core settings, core tor
    TransactionsDiModule(), // Depends on core wallet, core swaps, core exchange, core payjoin, core labels, core settings
    WalletDiModule(), // Depends on core wallet, core swaps, core settings, core tor, core ark
    WithdrawDiModule(), // Depends on core exchange, core settings
  ];

  for (final module in featureModules) {
    // By registering in phases, we ensure that dependencies are resolved
    // correctly and there is a clear direction of dependency flow.
    await module.registerFrameworksAndDrivers();
    await module.registerDrivenAdapters();
    await module.registerApplicationServices();
    await module.registerUseCases();
    await module.registerDrivingAdapters();
  }
}
