import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/data/auto_swap_settings_repository_impl.dart';
import 'package:bb_mobile/core/swaps/data/swap_server_setting_repository.dart';
import 'package:bb_mobile/core/swaps/data/swaps_adapters.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/auto_swap_settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_history_repository.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/disable_autoswap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/disable_autoswap_warning_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart' as wallet;
import 'package:swaps/swaps.dart';

class SwapsLocator {
  static Future<void> registerDatasources(GetIt locator) async {
    // The engine stays silent unless the app wires a logger.
    swapsLog = const AppSwapsLog();

    locator.registerLazySingleton<SwapServerSettingRepository>(
      SwapServerSettingRepository.new,
    );
    // Read once here (setup is async); a changed server takes effect on the
    // next launch.
    final boltzUrl = await locator<SwapServerSettingRepository>().fetch();
    locator.registerLazySingleton<SwapStorage>(
      () => SwapStorage(
        rows: DriftSwapRowStore(locator<SqliteDatabase>()),
        secrets: SecureSecretStore(
          locator<KeyValueStorageDatasource<String>>(
            instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
          ),
        ),
      ),
    );
    locator.registerLazySingleton<BoltzDatasource>(
      () => BoltzDatasource(url: boltzUrl, boltzStore: locator<SwapStorage>()),
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<SwapsAppGlue>(
      () => SwapsAppGlue(
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerLazySingleton<BoltzSwapRepository>(
      () {
        final glue = locator<SwapsAppGlue>();
        final fees = locator<FeesRepository>();
        final addresses = locator<WalletAddressRepository>();
        final walletTxs = locator<WalletTransactionRepository>();
        return BoltzSwapRepository(
          boltz: locator<BoltzDatasource>(),
          isTestnet: false,
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
            return SwapWalletTx(txId: tx.txId, isIncoming: tx.isIncoming);
          },
          walletTxs: (walletId, {bool sync = false}) async {
            final txs = await walletTxs.getWalletTransactions(
              walletId: walletId,
              sync: sync,
            );
            return [
              for (final tx in txs)
                SwapWalletTx(txId: tx.txId, isIncoming: tx.isIncoming),
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
                    isTestnet: isTestnet,
                    isLiquid: isLiquid,
                  ),
                );
                return options.toAbsolute(txSize).fastest.value.toInt();
              },
          wallets: glue.wallets,
          masterSeedSource: glue.masterSeedSource,
        );
      },
      instanceName:
          LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
    );
    locator.registerLazySingleton<SwapRepository>(
      () => locator<BoltzSwapRepository>(
        instanceName:
            LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
      ),
    );
    locator.registerLazySingleton<SwapWatcher>(
      () => SwapWatcher(repo: locator<SwapRepository>()),
    );
    locator.registerLazySingleton<SwapHistoryRepository>(
      () => _SwapHistoryAdapter(locator<SwapRepository>()),
    );
    locator.registerLazySingleton<AutoSwapSettingsRepository>(
      () => AutoSwapSettingsRepositoryImpl(
        locator<SqliteDatabase>(),
        locator<SettingsRepository>(),
      ),
    );
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

/// Read-only history view the transactions feature consumes.
class _SwapHistoryAdapter implements SwapHistoryRepository {
  final SwapRepository _repo;

  _SwapHistoryAdapter(this._repo);

  @override
  Future<List<Swap>> getAllSwaps({String? walletId}) =>
      _repo.all(walletId: walletId);

  @override
  Future<Swap?> getSwapByTxId(String txId) =>
      (_repo as BoltzSwapRepository).getSwapByTxId(txId);
}
