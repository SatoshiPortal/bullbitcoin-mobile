import 'package:bb_mobile/core/background_tasks/locator.dart';
import 'package:bb_mobile/core/background_tasks/tasks.dart';
import 'package:bb_mobile/core/status/domain/usecases/check_all_service_status_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lwk/lwk.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void backgroundTasksHandler() {
  Workmanager().executeTask((task, inputData) async {
    return await tasksHandler(task);
  });
}

Future<bool> tasksHandler(String task) async {
  final startTime = DateTime.now();

  await dotenv.load(isOptional: true);
  await Bull.initLogs();
  await LibLwk.init();

  await BackgroundTasksLocator.setup();

  try {
    final syncWalletUsecase = backgroundLocator<SyncWalletUsecase>();
    final getWalletsUsecase = backgroundLocator<GetWalletsUsecase>();
    final restartSwapWatcherUsecase =
        backgroundLocator<RestartSwapWatcherUsecase>();
    final checkAllServiceStatusUsecase =
        backgroundLocator<CheckAllServiceStatusUsecase>();

    final backgroundTask = BackgroundTask.fromName(task);

    switch (backgroundTask) {
      case BackgroundTask.bitcoinSync:
        final wallets = await getWalletsUsecase.execute(onlyBitcoin: true);
        for (final wallet in wallets) {
          await syncWalletUsecase.execute(wallet);
          log.fine('Bitcoin Wallet ${wallet.id} synced');
        }
      case BackgroundTask.liquidSync:
        final wallets = await getWalletsUsecase.execute(onlyLiquid: true);
        for (final wallet in wallets) {
          await syncWalletUsecase.execute(wallet);
          log.fine('Liquid Wallet ${wallet.id} synced');
        }
      case BackgroundTask.swapsSync:
        final wallets = await getWalletsUsecase.execute();
        if (wallets.isEmpty) log.warning('No wallets to sync');
        await restartSwapWatcherUsecase.execute();
      case BackgroundTask.logsPrune:
        await log.prune();
      case BackgroundTask.servicesCheck:
        final wallets = await getWalletsUsecase.execute();
        if (wallets.isEmpty) log.warning('No wallets to check services status');
        final defaultWallet = wallets.firstWhere((w) => w.isDefault);
        final network = defaultWallet.network;
        await checkAllServiceStatusUsecase.execute(network: network);
    }

    final elapsedTime = DateTime.now().difference(startTime).inSeconds;
    log.config('Background task $task completed in $elapsedTime seconds');
    return Future.value(true);
  } catch (e) {
    log.severe('Background task $task failed: $e');
    return Future.value(false);
  }
}
