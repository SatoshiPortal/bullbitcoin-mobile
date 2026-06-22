import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/fees/data/fees_repository.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_datasource.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/data/services/swap_watcher.dart';
import 'package:bb_mobile/core/swaps/domain/ports/blockchain_port.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/auto_swap_execution_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/create_chain_swap_to_external_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/create_chain_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/decode_invoice_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/disable_autoswap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/disable_autoswap_warning_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swaps_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/process_ongoing_swaps_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/process_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/rescue_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restore_swaps_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/update_paid_chain_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/interface_adapters/blockchain_adapter.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:get_it/get_it.dart';

class SwapsLocator {
  static Future<void> registerDatasources(GetIt locator) async {
    locator.registerLazySingleton<BoltzStorageDatasource>(
      () => BoltzStorageDatasource(
        secureSwapStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
        localSwapStorage: locator<SqliteDatabase>(),
      ),
    );
  }

  /// The current default bitcoin wallet (fingerprint + a lazy mnemonic reader)
  /// every swap master key is derived from. Keying by the fingerprint is what
  /// lets swap creation and restore always resolve the one canonical seed, even
  /// across wallet changes or an iOS reinstall.
  static Future<DefaultSwapWallet> _defaultSwapWallet(GetIt locator) async {
    final settings = await locator<SettingsRepository>().fetch();
    final wallets = await locator<WalletRepository>().getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
      environment: settings.environment,
    );
    if (wallets.isEmpty) {
      throw StateError(
        'No default bitcoin wallet to derive the swap master key',
      );
    }
    final fingerprint = wallets.first.masterFingerprint;
    return (
      fingerprint: fingerprint,
      mnemonic: () async {
        final seed = await locator<SeedRepository>().get(fingerprint);
        if (seed is! MnemonicSeed) {
          throw StateError('Default wallet seed is not a mnemonic');
        }
        return seed.mnemonicWords.join(' ');
      },
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<BoltzSwapRepository>(
      () => BoltzSwapRepository(
        boltz: BoltzDatasource(
          boltzStore: locator<BoltzStorageDatasource>(),
          defaultSwapWallet: () => _defaultSwapWallet(locator),
        ),
        isTestnet: false,
      ),
      instanceName:
          LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
    );
  }

  static void registerPorts(GetIt locator) {
    locator.registerLazySingleton<BlockchainPort>(
      () => BlockchainAdapter(
        broadcastLiquidTransactionUsecase:
            locator<BroadcastLiquidTransactionUsecase>(),
      ),
    );
  }

  static void registerServices(GetIt locator) {
    locator.registerLazySingleton<SwapWatcherService>(
      () => SwapWatcherService(
        boltzRepo: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        walletAddressRepository: locator<WalletAddressRepository>(),
        feesRepository: locator<FeesRepository>(),
      ),
      instanceName: LocatorInstanceNameConstants.boltzSwapWatcherInstanceName,
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<DecodeInvoiceUsecase>(
      () => DecodeInvoiceUsecase(
        boltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );

    locator.registerFactory<GetSwapLimitsUsecase>(
      () => GetSwapLimitsUsecase(
        boltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );

    locator.registerFactory<RestartSwapWatcherUsecase>(
      () => RestartSwapWatcherUsecase(
        swapWatcherService: locator<SwapWatcherService>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapWatcherInstanceName,
        ),
      ),
    );

    locator.registerFactory<GetSwapUsecase>(
      () => GetSwapUsecase(
        boltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );

    locator.registerFactory<GetSwapsUsecase>(
      () => GetSwapsUsecase(
        boltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );

    locator.registerFactory<WatchSwapUsecase>(
      () => WatchSwapUsecase(
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<RestoreSwapsUsecase>(
      () => RestoreSwapsUsecase(
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<RescueSwapUsecase>(
      () => RescueSwapUsecase(
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        settingsRepository: locator<SettingsRepository>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<UpdatePaidChainSwapUsecase>(
      () => UpdatePaidChainSwapUsecase(
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<GetAutoSwapSettingsUsecase>(
      () => GetAutoSwapSettingsUsecase(
        repository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<SaveAutoSwapSettingsUsecase>(
      () => SaveAutoSwapSettingsUsecase(
        repository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<DisableAutoswapWarningUsecase>(
      () => DisableAutoswapWarningUsecase(
        repository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<DisableAutoswapUsecase>(
      () => DisableAutoswapUsecase(
        repository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<AutoSwapExecutionUsecase>(
      () => AutoSwapExecutionUsecase(
        repository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        walletRepository: locator<WalletRepository>(),
        liquidWalletRepository: locator<LiquidWalletRepository>(),
        blockchainPort: locator<BlockchainPort>(),
        walletTxRepository: locator<WalletTransactionRepository>(),
        labelsFacade: locator<LabelsFacade>(),
      ),
    );
    locator.registerFactory<CreateChainSwapUsecase>(
      () => CreateChainSwapUsecase(
        walletRepository: locator<WalletRepository>(),
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<CreateChainSwapToExternalUsecase>(
      () => CreateChainSwapToExternalUsecase(
        walletRepository: locator<WalletRepository>(),
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<ProcessOngoingSwapsUsecase>(
      () => ProcessOngoingSwapsUsecase(
        watcherService: locator<SwapWatcherService>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapWatcherInstanceName,
        ),
      ),
    );
    locator.registerFactory<ProcessSwapUsecase>(
      () => ProcessSwapUsecase(
        watcherService: locator<SwapWatcherService>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapWatcherInstanceName,
        ),
      ),
    );
  }
}
