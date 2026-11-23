import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/data/wallet_sync_binding.dart';

import 'domain/usecases/get_default_wallet_network_usecase.dart';
import 'domain/usecases/is_tor_required_usecase.dart';

import 'package:ark/funding.dart';
import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';

import 'package:sync/write.dart' show WalletNativeRuntime;

import 'package:secrets/secrets.dart';
import 'package:bb_mobile/features/wallet/data/sync_freezes_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/send/public/send_setup.dart'
    show BitcoinWalletRepository, LiquidWalletRepository;
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/transactions/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/get_wallet_transaction_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/get_wallet_transactions_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:get_it/get_it.dart';
import 'package:sync/sync.dart' show Sync, Wallet;

class WalletLocator {
  /// Resolves the runtime lazily so composition can wire ports before startup.
  static ({
    Future<Sync> Function() foreground,
    Future<Wallet> Function(String walletId) openWallet,
  })
  syncAccess(GetIt locator) => (
    foreground: () async => WalletSyncBinding.value(
      await locator<WalletNativeRuntime>().foreground(),
    ),
    openWallet: (walletId) async => WalletSyncBinding.value(
      await locator<WalletNativeRuntime>().wallet(
        await WalletSyncBinding.keyForId(
          locator<WalletRegistrations>(),
          walletId,
        ),
      ),
    ),
  );

  static Future<void> registerDatasources(GetIt locator) async {
    locator.registerLazySingleton<SyncFreezesDatasource>(
      () => SyncFreezesDatasource(
        sync: () async => WalletSyncBinding.value(
          await locator<WalletNativeRuntime>().foreground(),
        ),
      ),
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<BitcoinWalletRepository>(
      () => BitcoinWalletRepository(
        arkFundingGuard: locator<ArkFundingSigningGuard>(),
        walletRegistrations: locator<WalletRegistrations>(),
        wallet: locator<WalletNativeRuntime>().wallet,
        walletValuesDatasource: locator<SyncWalletValuesDatasource>(),
        secrets: locator<Secrets>(),
      ),
    );

    locator.registerLazySingleton<LiquidWalletRepository>(
      () => LiquidWalletRepository(
        walletRegistrations: locator<WalletRegistrations>(),
        secrets: locator<Secrets>(),
        wallet: locator<WalletNativeRuntime>().wallet,
        freezesDatasource: locator<SyncFreezesDatasource>(),
      ),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<GetWalletUsecase>(
      () => GetWalletUsecase(walletRepository: locator<WalletRepository>()),
    );
    locator.registerFactory<GetDefaultWalletNetworkUsecase>(
      () => GetDefaultWalletNetworkUsecase(locator<GetWalletsUsecase>()),
    );
    locator.registerFactory<IsTorRequiredUsecase>(
      () => IsTorRequiredUsecase(locator<WalletRepository>()),
    );
    locator.registerFactory<GetWalletsUsecase>(
      () => GetWalletsUsecase(
        settingsRepository: locator<ActiveEnvironmentReader>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<WatchStartedWalletSyncsUsecase>(
      () => WatchStartedWalletSyncsUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<WatchFinishedWalletSyncsUsecase>(
      () => WatchFinishedWalletSyncsUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<WatchElectrumSyncResultsUsecase>(
      () => WatchElectrumSyncResultsUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<CheckWalletSyncingUsecase>(
      () => CheckWalletSyncingUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );

    locator.registerFactory<GetWalletTransactionsUsecase>(
      () => GetWalletTransactionsUsecase(
        settingsRepository: locator<ActiveEnvironmentReader>(),
        walletTransactionRepository: locator<WalletTransactionRepository>(),
      ),
    );
    locator.registerFactory<GetWalletTransactionUsecase>(
      () => GetWalletTransactionUsecase(
        walletTransactionRepository: locator<WalletTransactionRepository>(),
      ),
    );
    locator.registerFactory<SyncWalletUsecase>(
      () => SyncWalletUsecase(walletRepository: locator<WalletRepository>()),
    );
  }
}
