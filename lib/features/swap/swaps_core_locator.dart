import 'package:bb_mobile/features/swap/domain/regtest_boltz_profile.dart';
import 'package:electrum/setup.dart';
import 'package:fees/fees.dart';
import 'package:preferences/preferences.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/features/autoswap/data/auto_swap_settings_repository_impl.dart';
import 'package:bb_mobile/core/swaps/data/swap_server_setting_repository_impl.dart';
import 'package:bb_mobile/features/autoswap/domain/repositories/auto_swap_settings_repository.dart';
import 'package:primitives/primitives.dart' show Err, NetworkEnv, Ok;
import 'package:bb_mobile/core/swaps/domain/entity/swap_server.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_server_setting_repository.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/disable_autoswap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/disable_autoswap_warning_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/swap_engine_switcher.dart';
import 'package:bb_mobile/core/swaps/swaps_adapters.dart';

import 'package:bb_mobile/features/address_view/domain/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network, NetworkX;
import 'package:bb_mobile/features/transactions/domain/repositories/wallet_transaction_repository.dart';
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

    locator.registerLazySingleton<SwapStorage>(
      () => SwapStorage(
        rows: DriftSwapRowStore(locator<BoltzSwapsDatabase>()),
        secrets: locator<Secrets>().swapKeychain,
      ),
    );
    locator.registerLazySingleton<SwapStorage>(
      () => locator<SwapStorage>().regtestView(
        rows: DriftSwapRowStore(
          locator<BoltzSwapsDatabase>(instanceName: 'regtest'),
        ),
      ),
      instanceName: 'regtest',
    );
  }

  static Future<void> registerRepositories(GetIt locator) async {
    final environment = ((await locator<Preferences>().fetch()).fold(
      (value) => value,
      (failure) => throw Exception('Preferences read failed'),
    )).environment;
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
        settingsRepository: locator<Preferences>(),
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
        locator<BoltzSwapsDatabase>(),
        locator<Preferences>(),
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
    final fees = locator<Fees>();
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
        settingsRepository: locator<Preferences>(),
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
            final network = Network.fromEnvironment(
              environment: environment,
              isLiquid: isLiquid,
            ).shared;
            return switch (await fees.estimate(network)) {
              Ok(:final value) =>
                value.toAbsolute(txSize).fastest.value.toInt(),
              Err() => throw Exception('Fee estimation unavailable'),
            };
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
