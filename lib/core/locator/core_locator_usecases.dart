import 'package:bb_mobile/core/blockchain/domain/repositories/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bitcoin_price_datasource.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_rate_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/create_label_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/services/payjoin_watcher_service.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/file_system_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_backup_key_from_default_seed_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_backup_from_file_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/disconnect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_encrypted_vault_from_backup_key_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_folder_path_usecase.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/repositories/word_list_repository.dart';
import 'package:bb_mobile/core/seed/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/core/seed/domain/usecases/find_mnemonic_words_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/usecases/convert_currency_to_sats_amount_usecase.dart';
import 'package:bb_mobile/core/settings/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_currency_usecase.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_environment_usecase.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_hide_amounts_usecase.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_language_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/services/swap_watcher_service.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/tor/domain/repositories/tor_repository.dart';
import 'package:bb_mobile/core/tor/domain/usecases/check_for_tor_initialization.dart';
import 'package:bb_mobile/core/tor/domain/usecases/initialize_tor_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/build_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transactions_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/recover_wallet/domain/usecases/recover_wallet_use_case.dart';
import 'package:bb_mobile/locator.dart';

Future<void> registerUsecases() async {
  // Use cases
  locator.registerFactory<CreateBackupKeyFromDefaultSeedUsecase>(
    () => CreateBackupKeyFromDefaultSeedUsecase(
      seedRepository: locator<SeedRepository>(),
      walletRepository: locator<WalletRepository>(),
    ),
  );
  // Register InitializeTorUsecase using TorRepository
  locator.registerFactory<InitializeTorUsecase>(
    () => InitializeTorUsecase(locator<TorRepository>()),
  );
  locator.registerFactory<CheckForTorInitializationOnStartupUsecase>(
    () => CheckForTorInitializationOnStartupUsecase(
      walletRepository: locator<WalletRepository>(),
    ),
  );
  locator.registerFactory<ConnectToGoogleDriveUsecase>(
    () => ConnectToGoogleDriveUsecase(locator<GoogleDriveRepository>()),
  );

  locator.registerFactory<FetchLatestGoogleDriveBackupUsecase>(
    () => FetchLatestGoogleDriveBackupUsecase(locator<GoogleDriveRepository>()),
  );

  locator.registerFactory<DisconnectFromGoogleDriveUsecase>(
    () => DisconnectFromGoogleDriveUsecase(locator<GoogleDriveRepository>()),
  );

  locator.registerFactory<SelectFileFromPathUsecase>(
    () => SelectFileFromPathUsecase(locator<FileSystemRepository>()),
  );

  locator.registerFactory<SelectFolderPathUsecase>(
    () => SelectFolderPathUsecase(locator<FileSystemRepository>()),
  );
  locator.registerFactory<FetchBackupFromFileSystemUsecase>(
    () => FetchBackupFromFileSystemUsecase(),
  );

  locator.registerFactory<RestoreEncryptedVaultFromBackupKeyUsecase>(
    () => RestoreEncryptedVaultFromBackupKeyUsecase(
      recoverBullRepository: locator<RecoverBullRepository>(),
      walletRepository: locator<WalletRepository>(),
      createDefaultWalletsUsecase: locator<CreateDefaultWalletsUsecase>(),
    ),
  );
  locator.registerFactory<FindMnemonicWordsUsecase>(
    () => FindMnemonicWordsUsecase(
      wordListRepository: locator<WordListRepository>(),
    ),
  );
  locator.registerFactory<GetEnvironmentUsecase>(
    () => GetEnvironmentUsecase(
      settingsRepository: locator<SettingsRepository>(),
    ),
  );
  locator.registerFactory<GetBitcoinUnitUsecase>(
    () => GetBitcoinUnitUsecase(
      settingsRepository: locator<SettingsRepository>(),
    ),
  );
  locator.registerFactory<GetHideAmountsUsecase>(
    () => GetHideAmountsUsecase(
      settingsRepository: locator<SettingsRepository>(),
    ),
  );
  locator.registerFactory<GetLanguageUsecase>(
    () => GetLanguageUsecase(
      settingsRepository: locator<SettingsRepository>(),
    ),
  );
  locator.registerFactory<GetCurrencyUsecase>(
    () => GetCurrencyUsecase(settingsRepository: locator<SettingsRepository>()),
  );
  locator.registerFactory<CreateDefaultWalletsUsecase>(
    () => CreateDefaultWalletsUsecase(
      seedRepository: locator<SeedRepository>(),
      settingsRepository: locator<SettingsRepository>(),
      mnemonicSeedFactory: locator<MnemonicSeedFactory>(),
      walletRepository: locator<WalletRepository>(),
    ),
  );
  locator.registerFactory<GetWalletsUsecase>(
    () => GetWalletsUsecase(
      settingsRepository: locator<SettingsRepository>(),
      walletRepository: locator<WalletRepository>(),
    ),
  );
  locator.registerFactory<ReceiveWithPayjoinUsecase>(
    () => ReceiveWithPayjoinUsecase(
      payjoinRepository: locator<PayjoinRepository>(),
      settingsRepository: locator<SettingsRepository>(),
    ),
  );
  locator.registerFactory<SendWithPayjoinUsecase>(
    () =>
        SendWithPayjoinUsecase(payjoinRepository: locator<PayjoinRepository>()),
  );
  locator.registerFactory<WatchPayjoinUsecase>(
    () => WatchPayjoinUsecase(
      payjoinWatcherService: locator<PayjoinWatcherService>(),
    ),
  );

  locator.registerFactory<BuildTransactionUsecase>(
    () => BuildTransactionUsecase(
      payjoinRepository: locator<PayjoinRepository>(),
      walletManagerService: locator<WalletManagerService>(),
    ),
  );
  final exchangeRateRepository = ExchangeRateRepositoryImpl(
    bitcoinPriceDatasource: locator<BitcoinPriceDatasource>(),
  );
  locator.registerFactory<GetAvailableCurrenciesUsecase>(
    () => GetAvailableCurrenciesUsecase(
      exchangeRateRepository: exchangeRateRepository,
    ),
  );
  locator.registerFactory<ConvertSatsToCurrencyAmountUsecase>(
    () => ConvertSatsToCurrencyAmountUsecase(
      exchangeRateRepository: exchangeRateRepository,
      settingsRepository: locator<SettingsRepository>(),
    ),
  );
  locator.registerFactory<ConvertCurrencyToSatsAmountUsecase>(
    () => ConvertCurrencyToSatsAmountUsecase(
      exchangeRateRepository: exchangeRateRepository,
      settingsRepository: locator<SettingsRepository>(),
    ),
  );
  locator.registerFactory<WatchSwapUsecase>(
    () => WatchSwapUsecase(
      watcherService: locator<SwapWatcherService>(
        instanceName: LocatorInstanceNameConstants.boltzSwapWatcherInstanceName,
      ),
    ),
  );

  locator.registerFactory<GetWalletTransactionsUsecase>(
    () => GetWalletTransactionsUsecase(
      walletManager: locator<WalletManagerService>(),
      testnetSwapRepository: locator<SwapRepository>(
        instanceName:
            LocatorInstanceNameConstants.boltzTestnetSwapRepositoryInstanceName,
      ),
      mainnetSwapRepository: locator<SwapRepository>(
        instanceName:
            LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
      ),
    ),
  );
  locator.registerFactory<BroadcastLiquidTransactionUsecase>(
    () => BroadcastLiquidTransactionUsecase(
      liquidBlockchainRepository: locator<LiquidBlockchainRepository>(),
    ),
  );
  locator.registerFactory<BroadcastBitcoinTransactionUsecase>(
    () => BroadcastBitcoinTransactionUsecase(
      bitcoinBlockchainRepository: locator<BitcoinBlockchainRepository>(),
    ),
  );
  locator.registerFactory<BroadcastOriginalTransactionUsecase>(
    () => BroadcastOriginalTransactionUsecase(
      walletRepository: locator<WalletRepository>(),
      payjoinRepository: locator<PayjoinRepository>(),
    ),
  );
  locator.registerFactory<RecoverOrCreateWalletUsecase>(
    () => RecoverOrCreateWalletUsecase(
      settingsRepository: locator<SettingsRepository>(),
      mnemonicSeedFactory: locator<MnemonicSeedFactory>(),
      walletRepository: locator<WalletRepository>(),
      seedRepository: locator<SeedRepository>(),
    ),
  );
  locator.registerFactory<RestartSwapWatcherUsecase>(
    () => RestartSwapWatcherUsecase(
      swapWatcherService: locator<SwapWatcherService>(
        instanceName: LocatorInstanceNameConstants.boltzSwapWatcherInstanceName,
      ),
    ),
  );

  // Register GetSwapLimitsUsecase with mainnet and testnet repositories
  locator.registerFactory<GetSwapLimitsUsecase>(
    () => GetSwapLimitsUsecase(
      mainnetSwapRepository: locator<SwapRepository>(
        instanceName:
            LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
      ),
      testnetSwapRepository: locator<SwapRepository>(
        instanceName:
            LocatorInstanceNameConstants.boltzTestnetSwapRepositoryInstanceName,
      ),
    ),
  );

  locator.registerFactory<CreateLabelUsecase>(
    () => CreateLabelUsecase(
      labelRepository: locator<LabelRepository>(),
      walletRepository: locator<WalletRepository>(),
    ),
  );
}
