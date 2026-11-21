import 'package:bb_mobile/features/swap/domain/regtest_boltz_profile.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:secrets/secrets.dart';
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
import 'package:bb_mobile/core/swaps/switchable_swap_engine.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' as wallet;
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:swaps/swaps.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:get_it/get_it.dart';
import 'package:sync/sync.dart' show WalletConnectionPort;

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
      () =>
          SwapStorage(rows: rowStore, secrets: locator<Secrets>().swapKeychain),
    );
    locator.registerLazySingleton<SwapStorage>(
      () => locator<SwapStorage>().regtestView(
        rows: DriftSwapRowStore(
          BoltzSwapsDatabase(
            driftDatabase(
              name: 'boltz_swaps_regtest',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationDocumentsDirectory,
                shareAcrossIsolates: true,
                setup: (database) {
                  database.execute('PRAGMA busy_timeout = 2000;');
                  database.execute('PRAGMA journal_mode = WAL;');
                  database.execute('PRAGMA synchronous = FULL;');
                },
              ),
            ),
          ),
        ),
      ),
      instanceName: 'regtest',
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
        secrets: locator<Secrets>(),
      ),
    );
    final initialServer = environment.networkEnv == NetworkEnv.regtest
        ? null
        : await locator<SwapServerSettingRepository>().fetch(
            isTestnet: environment.networkEnv == NetworkEnv.testnet,
          );
    locator.registerLazySingleton<SwitchableSwapEngine>(
      () => SwitchableSwapEngine(
        _buildEngine(
          locator,
          environment: environment.networkEnv,
          server: initialServer,
        ),
      ),
    );
    locator.registerLazySingleton<SwapStore>(
      () => locator<SwitchableSwapEngine>(),
    );
    locator.registerLazySingleton<SwapResolver>(
      () => locator<SwitchableSwapEngine>(),
    );
    locator.registerLazySingleton<BoltzSwaps>(
      () => locator<SwitchableSwapEngine>(),
    );
    locator.registerLazySingleton<SwapWatcher>(
      () => SwapWatcher(
        store: locator<SwapStore>(),
        resolvers: {SwapProvider.boltz: locator<SwapResolver>()},
      ),
    );
    locator.registerLazySingleton<SwapEngineSwitcher>(
      () => SwapEngineSwitcher(
        settingsRepository: locator<SettingsRepository>(),
        engine: locator<SwitchableSwapEngine>(),
        swapWatcher: locator<SwapWatcher>(),
        build: ({required environment}) async => _buildEngine(
          locator,
          environment: environment,
          server: environment == NetworkEnv.regtest
              ? null
              : await locator<SwapServerSettingRepository>().fetch(
                  isTestnet: environment == NetworkEnv.testnet,
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
    required NetworkEnv environment,
    required SwapServer? server,
  }) {
    final profile = RegtestBoltzProfile.forNetwork(environment);
    final url =
        profile?.api.toString() ??
        server
            ?.forEnvironment(isTestnet: environment == NetworkEnv.testnet)
            .host;
    if (url == null) throw StateError('Missing Boltz backend');
    final storage = environment == NetworkEnv.regtest
        ? locator<SwapStorage>(instanceName: 'regtest')
        : locator<SwapStorage>();
    log.info('[Swaps] boltz datasource url="$url" network=${environment.name}');
    final glue = locator<SwapsAppGlue>();
    final fees = locator<FeesRepository>();
    final addresses = locator<WalletAddressRepository>();
    final walletTxs = locator<WalletTransactionRepository>();
    final boltz = BoltzSwapRepository.connect(
      url: url,
      storage: storage,
      environment: environment,
      webSocketUrl: profile?.webSocket.toString(),
      bitcoinExplorerUrl: profile?.bitcoinExplorer.toString(),
      liquidExplorerUrl: profile?.liquidExplorer.toString(),
      electrum: AppElectrumRunner(locator<ElectrumServersPort>()),
      lockupChain: AppLockupChain(
        locator<WalletConnectionPort>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
      newAddressFor: (walletId) async =>
          (await addresses.generateNewReceiveAddress(walletId: walletId))
              .address,
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
            required NetworkEnv environment,
          }) async {
            final options = await fees.getNetworkFees(
              network: wallet.Network.fromEnvironment(
                environment: environment,
                isLiquid: isLiquid,
              ),
            );
            return options.toAbsolute(txSize).fastest.value.toInt();
          },
      wallets: glue.wallets,
      swapMasterKeySource: glue.swapMasterKey,
    );
    return (
      store: SwapStoreImpl(storage: storage, environment: environment),
      boltz: boltz,
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<GetSwapUsecase>(
      () => GetSwapUsecase(locator<SwapStore>()),
    );
    locator.registerFactory<GetSwapsUsecase>(
      () => GetSwapsUsecase(locator<SwapStore>()),
    );
    locator.registerFactory<WatchSwapUsecase>(
      () => WatchSwapUsecase(locator<SwapStore>()),
    );
    locator.registerFactory<RestoreSwapsUsecase>(
      () => RestoreSwapsUsecase(locator<SwapResolver>(), locator<SwapStore>()),
    );
    locator.registerFactory<RescueSwapUsecase>(
      () => RescueSwapUsecase(
        locator<SwapResolver>(),
        locator<SwapStore>(),
        locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<RetrySwapUsecase>(
      () => RetrySwapUsecase(locator<SwapWatcher>()),
    );
    locator.registerFactory<RetryOngoingSwapsUsecase>(
      () => RetryOngoingSwapsUsecase(locator<SwapWatcher>()),
    );
    locator.registerFactory<CreateBitcoinToLightningSwapUsecase>(
      () => CreateBitcoinToLightningSwapUsecase(
        locator<BoltzSwaps>(),
        locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<CreateLiquidToLightningSwapUsecase>(
      () => CreateLiquidToLightningSwapUsecase(
        locator<BoltzSwaps>(),
        locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<CreateLightningToBitcoinSwapUsecase>(
      () => CreateLightningToBitcoinSwapUsecase(
        locator<BoltzSwaps>(),
        locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<CreateLightningToLiquidSwapUsecase>(
      () => CreateLightningToLiquidSwapUsecase(
        locator<BoltzSwaps>(),
        locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<CreateBitcoinToLiquidSwapUsecase>(
      () => CreateBitcoinToLiquidSwapUsecase(
        locator<BoltzSwaps>(),
        locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<CreateLiquidToBitcoinSwapUsecase>(
      () => CreateLiquidToBitcoinSwapUsecase(
        locator<BoltzSwaps>(),
        locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<GetSwapLimitsAndFeesUsecase>(
      () => GetSwapLimitsAndFeesUsecase(locator<BoltzSwaps>()),
    );
    locator.registerFactory<RecordSwapLockupUsecase>(
      () => RecordSwapLockupUsecase(
        locator<SwapResolver>(),
        locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<RecordPendingSwapLockupUsecase>(
      () => RecordPendingSwapLockupUsecase(locator<SwapResolver>()),
    );
    locator.registerFactory<DropPendingSwapLockupUsecase>(
      () => DropPendingSwapLockupUsecase(locator<SwapResolver>()),
    );
    locator.registerFactory<LogSwapCensusUsecase>(
      () => LogSwapCensusUsecase(locator<SwapStore>()),
    );
    locator.registerFactory<GetSwapMasterKeyUsecase>(
      () => GetSwapMasterKeyUsecase(locator<BoltzSwaps>()),
    );
    locator.registerFactory<GetSwapMnemonicUsecase>(
      () => GetSwapMnemonicUsecase(locator<BoltzSwaps>()),
    );
    locator.registerFactory<DeleteSwapMasterKeyUsecase>(
      () => DeleteSwapMasterKeyUsecase(locator<BoltzSwaps>()),
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
