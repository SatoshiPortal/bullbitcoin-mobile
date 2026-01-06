import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/address_view/address_view_di_module.dart';
import 'package:bb_mobile/features/all_seed_view/all_seed_view_di_module.dart';
import 'package:bb_mobile/features/app_startup/app_startup_di_module.dart';
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
    // TODO: Remove Ark dependency from Settings feature and merge with core settings and define a clear api/facade for it
    SettingsDiModule(), // Depends on core settings, core storage, core ark
    // Remove core settings dependency and merge with core tor in features/tor and define a clear api/facade for it
    TorSettingsDiModule(), // Depends on core settings
    // TODO: Merge with core mempool in features/mempool and define a clear api/facade for it
    MempoolSettingsDiModule(), // Depends on core mempool
    // TODO: Move core fees to features and define a clear api/facade for it
    PinCodeDiModule(), // Depends on core storage;
    // TODO: Move core labels to features and define a clear api/facade for it
    // TODO: Merge core seed and seed view features into one feature and define a clear api/facade for it
    LegacySeedViewDiModule(), // Depends on core storage
    AllSeedViewDiModule(), // Depends on core seed, core wallet
    // TODO: Merge core bitbox in features/bitbox and define a clear api/facade for it
    BitBoxDiModule(), // Depends on core bitbox
    // TODO: Merge core ledger in features/ledger and define a clear api/facade for it
    LedgerDiModule(), // Depends on core ledger
    // TODO: Analyze if it makes sense to have a single hardware wallets feature instead of separate bitbox/ledger/etc. features
    //  It would make sense if there is shared logic between different hardware wallets that can be abstracted away, which I think there is since
    //  the same operations are performed (connect, sign tx, sign message, etc.) just with different implementations under the hood.
    // TODO: Move core bip85 to features, refactor how it uses the seed feature and define a clear api/facade for it
    // TODO: Remove the exchange dependency since the price feature itself or core could just have a bullbitcoin api client that can be used by the price feature independently of the exchange feature
    BitcoinPriceDiModule(), // Depends on core exchange, core settings
    // TODO: Merge Broadcast Signed Tx, core Blockchain and Electrum Settings and core Electrum in one Blockchain (Backends) feature and
    //  define a clear api/facade to broadcast transactions and get the prioritized blockchain servers and optionally other blockchain related data
    BroadcastSignedTxDiModule(), // Depends on core blockchain
    ElectrumSettingsDiModule(), // Depends on core electrum
    Bip85EntropyDiModule(), // Depends on core bip85, core seed
    // TODO: Eliminate the dependency on swaps, merge core wallet in features/wallet and define a clear api/facade for it
    //  Also merge Ark wallet stuff in here since Ark is just another wallet implementation
    //  This will require quite some refactoring though.
    WalletDiModule(), // Depends on core wallet, core swaps, core settings, core tor, core ark
    // TODO: Merge mnemonic and watch-only wallet import features into the wallets feature
    ImportMnemonicDiModule(), // Depends on core wallet
    ImportWatchOnlyWalletDiModule(), // Depends on core wallet
    // TODO: Merge onboarding feature with wallets feature since it is meant to create/restore a wallet
    OnboardingDiModule(), // Depends on core wallet
    // TODO: Merge core exchange in features/exchange and define a clear api/facade for it
    ExchangeDiModule(), // Depends on core exchange
    // TODO: Refactor to use ports to other features and better domain definitions
    //. no api/facade is needed since nothing else depends on it
    AppStartupDiModule(), // Depends on core settings, core wallet, core seed, app_unlock, core storage, test_wallet_backup, pin_code, core tor
    // TODO: Rename to Address Management feature and refactor to use a wallet address port and labels port
    //  no api/facade is needed since nothing else depends on it for now
    AddressViewDiModule(), // Depends on core wallet
    RecipientsDiModule(), // TODO: frameworks should be moved to core (FlutterSecureStorage, BullbitcoinApiKeyProvider, Dio instances)
    // TODO: Analyze what should be owned by fund exchange feature that is now in core exchange
    //  no api/facade is needed since nothing else depends on it
    FundExchangeDiModule(), // Depends on core exchange
    // TODO: Refactor with ports to wallets, bip85 and seed features
    //  no api/facade is needed since nothing else depends on it
    BackupSettingsDiModule(), // Depends on core wallet, core settings
    // TODO: Mege with Backup Settings into one Backups feature
    //  no api/facade is needed since nothing else depends on it
    TestWalletBackupDiModule(), // Depends on core wallet, core seed, core settings
    // TODO: Merge core swaps in features/swap and define a clear api/facade for it
    SwapDiModule(), // Depends on core swaps, core wallet, core seed, core blockchain, core fees, send; NOTE: many use cases might be duplicates from send
    // TODO: Move core payjoin to features/payjoin, refactor and define a clear api/facade for it
    // TODO: Analyze what should be owned by withdraw feature that is now in core exchange
    //  no api/facade is needed since nothing else depends on it
    WithdrawDiModule(), // Depends on core exchange, core settings
    // TODO: refactor with ports to other features and better domain definitions
    // and define a clear api/facade for other features to use
    // TODO: Merge with core status in features/status and refactor with ports of
    //  other features that expose their status info (wallet, exchange, etc.)
    StatusCheckDiModule(), // Depends on core status, core wallet
    SendDiModule(), // Depends on core wallet, core swaps, core seed, core settings, core blockchain, core fees, core payjoin, core exchange
    // TODO: Add replace by fee feature to Send feature, since it needs to repeat the prepare (build and sign tx) and confirm (broadcast tx) flow again
    //  no api/facade is needed since nothing else depends on it, it's all internal to send feature and can be navigated to the replace by fee flow from for example
    //  the transaction details screen in the Transaction History feature, the Transaction History feature shouldn't depend on the Send feature for this.
    ReplaceByFeeDiModule(), // Depends on core wallet
    // TODO: refactor with ports to other features and better domain definitions
    // and define a clear api/facade for other features to use
    ReceiveDiModule(), // Depends on core wallet, core swaps, core seed, core exchange, core payjoin, core labels, core settings
    // TODO: refactor with ports to other features and better domain definitions
    //  no api/facade is needed since nothing else depends on it
    TransactionsDiModule(), // Depends on core wallet, core swaps, core exchange, core payjoin, core labels, core settings
    // TODO: Analyze what should be owned by dca feature that is now in core exchange
    //  refactor with ports to other features (receive) and better domain definitions
    //  no api/facade is needed since nothing else depends on it
    DcaDiModule(), // Depends on core exchange, core settings, core wallet
    // TODO: Analyze what should be owned by sell feature that is now in core exchange
    //  refactor with ports to other features and better domain definitions
    //  no api/facade is needed since nothing else depends on it
    SellDiModule(), // Depends on core exchange, core blockchain, core fees, core wallet, core labels, send, core settings
    // TODO: Analyze what should be owned by pay feature that is now in core exchange
    //  refactor with ports to other features and better domain definitions
    //  no api/facade is needed since nothing else depends on it
    PayDiModule(), // Depends on core exchange, core blockchain, core fees, core wallet, send, recipients
    // TODO: Analyze what should be owned by buy feature that is now in core exchange
    //  refactor with ports to other features and better domain definitions
    //  no api/facade is needed since nothing else depends on it
    BuyDiModule(), // Depends on core wallet, core exchange, core fees, core settings
    // TODO: Refactor so it uses send, receive and swaps features via ports
    //  no api/facade is needed since nothing else depends on it
    AutoSwapDiModule(), // Depends on core swaps, core settings, core wallet
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
