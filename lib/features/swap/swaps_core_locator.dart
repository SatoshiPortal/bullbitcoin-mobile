import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/boltz_swaps_db_migration.dart';
import 'package:bb_mobile/features/autoswap/data/auto_swap_settings_repository_impl.dart';
import 'package:bb_mobile/core/swaps/data/swap_server_setting_repository_impl.dart';
import 'package:bb_mobile/features/autoswap/domain/repositories/auto_swap_settings_repository.dart';
import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:bb_mobile/core/swaps/domain/entity/swap_server.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_server_setting_repository.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/disable_autoswap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/disable_autoswap_warning_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/swap_engine_switcher.dart';
import 'package:bb_mobile/core/swaps/swaps_adapters.dart';
import 'package:bb_mobile/core/swaps/switchable_swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' as wallet;
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:swaps/swaps.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:get_it/get_it.dart';
import 'package:secrets/secrets.dart';

/// Wires the self-contained `swaps` engine package to the app: storage
/// backends, wallet/fee/electrum callbacks, the watcher, and the usecases
/// blocs consume. This is the only place the app knows how the engine is
/// assembled.
class SwapsLocator {
  static Future<void> registerDatasources(GetIt locator) async {
    swapsLog = const AppSwapsLog();

    locator.registerLazySingleton<BoltzSwapsDatabase>(
      () => BoltzSwapsDatabase(openBoltzSwapsDbConnection()),
    );
    final rowStore = DriftSwapRowStore(locator<BoltzSwapsDatabase>());
    locator.registerLazySingleton<SwapStorage>(
      () => SwapStorage(
        rows: rowStore,
        secrets: SecureSecretStore(
          locator<KeyValueStorageDatasource<String>>(
            instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
          ),
        ),
      ),
    );
    await BoltzSwapsDbMigration(
      appDb: locator<SqliteDatabase>(),
      swapsDb: locator<BoltzSwapsDatabase>(),
      rows: rowStore,
    ).run();
  }

  static Future<void> registerRepositories(GetIt locator) async {
    final environment =
        (await locator<SettingsRepository>().fetch()).environment;
    locator.registerLazySingleton<SwapServerSettingRepository>(
      SwapServerSettingRepositoryImpl.new,
    );
    locator.registerLazySingleton<SwapsAppGlue>(
      () => SwapsAppGlue(
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        secrets: locator<Secrets>(),
      ),
    );
    final initialServer = await locator<SwapServerSettingRepository>().fetch(
      isTestnet: !environment.isMainnet,
    );
    locator.registerLazySingleton<SwitchableSwapRepository>(
      () => SwitchableSwapRepository(
        _buildEngine(
          locator,
          isTestnet: !environment.isMainnet,
          server: initialServer,
        ),
      ),
    );
    locator.registerFactory<BoltzSwapRepository>(
      () => locator<SwitchableSwapRepository>().current,
      instanceName:
          LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
    );
    locator.registerLazySingleton<SwapRepository>(
      () => locator<SwitchableSwapRepository>(),
    );
    locator.registerLazySingleton<SwapWatcher>(
      () => SwapWatcher(repo: locator<SwapRepository>()),
    );
    locator.registerLazySingleton<SwapEngineSwitcher>(
      () => SwapEngineSwitcher(
        settingsRepository: locator<SettingsRepository>(),
        swapRepository: locator<SwitchableSwapRepository>(),
        swapWatcher: locator<SwapWatcher>(),
        build: ({required isTestnet}) async => _buildEngine(
          locator,
          isTestnet: isTestnet,
          server: await locator<SwapServerSettingRepository>().fetch(
            isTestnet: isTestnet,
          ),
        ),
      ),
      dispose: (switcher) => switcher.dispose(),
    );
    locator.registerLazySingleton<AutoSwapSettingsRepository>(
      () => AutoSwapSettingsRepositoryImpl(
        locator<SqliteDatabase>(),
        locator<SettingsRepository>(),
      ),
    );
  }

  static SwapEngineParts _buildEngine(
    GetIt locator, {
    required bool isTestnet,
    required SwapServer server,
  }) {
    final url = server.forEnvironment(isTestnet: isTestnet).host;
    log.info('[Swaps] boltz datasource url="$url" isTestnet=$isTestnet');
    final datasource = BoltzDatasource(
      url: url,
      boltzStore: locator<SwapStorage>(),
    );
    final glue = locator<SwapsAppGlue>();
    final fees = locator<FeesRepository>();
    final addresses = locator<WalletAddressRepository>();
    final walletTxs = locator<WalletTransactionRepository>();
    final repository = BoltzSwapRepository(
      boltz: datasource,
      isTestnet: isTestnet,
      electrum: AppElectrumRunner(locator<ElectrumServersPort>()),
      newAddressFor: (walletId) async =>
          (await addresses.generateNewReceiveAddress(
            walletId: walletId,
          )).address,
      walletTx: (txid, {required walletId}) async {
        final tx = await walletTxs.getWalletTransaction(
          txid,
          walletId: walletId,
        );
        if (tx == null) return null;
        return SwapWalletTx(
          txId: tx.txId,
          isIncoming: tx.isIncoming,
          spendsTxIds: [for (final i in tx.inputs) i.previousTxId],
        );
      },
      walletTxs: (walletId, {bool sync = false}) async {
        final txs = await walletTxs.getWalletTransactions(
          walletId: walletId,
          sync: sync,
        );
        return [
          for (final tx in txs)
            SwapWalletTx(
              txId: tx.txId,
              isIncoming: tx.isIncoming,
              spendsTxIds: [for (final i in tx.inputs) i.previousTxId],
            ),
        ];
      },
      fastestFee:
          ({
            required int txSize,
            required bool isLiquid,
            required bool isTestnet,
          }) async {
            final options = await fees.getNetworkFees(
              network: wallet.Network.fromEnvironment(
                environment: isTestnet
                    ? NetworkEnv.testnet
                    : NetworkEnv.mainnet,
                isLiquid: isLiquid,
              ),
            );
            return options.toAbsolute(txSize).fastest.value.toInt();
          },
      wallets: glue.wallets,
      swapMasterKeySource: glue.swapMasterKey,
    );
    return (repository: repository, datasource: datasource);
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<GetSwapUsecase>(
      () => GetSwapUsecase(swapRepository: locator<SwapRepository>()),
    );
    locator.registerFactory<GetSwapsUsecase>(
      () => GetSwapsUsecase(swapRepository: locator<SwapRepository>()),
    );
    locator.registerFactory<WatchSwapUsecase>(
      () => WatchSwapUsecase(swapRepository: locator<SwapRepository>()),
    );
    locator.registerFactory<RestoreSwapsUsecase>(
      () => RestoreSwapsUsecase(swapRepository: locator<SwapRepository>()),
    );
    locator.registerFactory<RescueSwapUsecase>(
      () => RescueSwapUsecase(
        swapRepository: locator<SwapRepository>(),
        swapWatcher: locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<RetrySwapUsecase>(
      () => RetrySwapUsecase(swapRepository: locator<SwapRepository>()),
    );
    locator.registerFactory<CreateChainSwapUsecase>(
      () => CreateChainSwapUsecase(
        swapRepository: locator<SwapRepository>(),
        swapWatcher: locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<CreateLightningSendSwapUsecase>(
      () => CreateLightningSendSwapUsecase(
        swapRepository: locator<SwapRepository>(),
        swapWatcher: locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<CreateLightningReceiveSwapUsecase>(
      () => CreateLightningReceiveSwapUsecase(
        swapRepository: locator<SwapRepository>(),
        swapWatcher: locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<GetSwapLimitsAndFeesUsecase>(
      () => GetSwapLimitsAndFeesUsecase(
        swapRepository: locator<SwapRepository>(),
      ),
    );
    locator.registerFactory<RecordSwapLockupUsecase>(
      () => RecordSwapLockupUsecase(
        swapRepository: locator<SwapRepository>(),
        swapWatcher: locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<LogSwapCensusUsecase>(
      () => LogSwapCensusUsecase(swapRepository: locator<SwapRepository>()),
    );
    locator.registerFactory<GetSwapMasterKeyUsecase>(
      () => GetSwapMasterKeyUsecase(
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<GetSwapMnemonicUsecase>(
      () => GetSwapMnemonicUsecase(
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<DeleteSwapMasterKeyUsecase>(
      () => DeleteSwapMasterKeyUsecase(
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<GetAutoSwapSettingsUsecase>(
      () => GetAutoSwapSettingsUsecase(
        repository: locator<AutoSwapSettingsRepository>(),
      ),
    );
    locator.registerFactory<SaveAutoSwapSettingsUsecase>(
      () => SaveAutoSwapSettingsUsecase(
        repository: locator<AutoSwapSettingsRepository>(),
      ),
    );
    locator.registerFactory<WatchAutoSwapSettingsUsecase>(
      () => WatchAutoSwapSettingsUsecase(
        repository: locator<AutoSwapSettingsRepository>(),
      ),
    );
    locator.registerFactory<DisableAutoswapWarningUsecase>(
      () => DisableAutoswapWarningUsecase(
        repository: locator<AutoSwapSettingsRepository>(),
      ),
    );
    locator.registerFactory<DisableAutoswapUsecase>(
      () => DisableAutoswapUsecase(
        repository: locator<AutoSwapSettingsRepository>(),
      ),
    );
  }
}
