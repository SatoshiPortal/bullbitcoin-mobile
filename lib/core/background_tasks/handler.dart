import 'package:bb_mobile/core/background_tasks/locator.dart';
import 'package:bb_mobile/core/background_tasks/tasks.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bb_mobile/main.dart';
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

  await Bull.initLogs();
  await LibLwk.init();

  await BackgroundTasksLocator.setup();

  try {
    final syncWalletUsecase = backgroundLocator<SyncWalletUsecase>();
    final getWalletsUsecase = backgroundLocator<GetWalletsUsecase>();
    final restartSwapWatcherUsecase =
        backgroundLocator<RestartSwapWatcherUsecase>();

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
        await restartSwapWatcherUsecase.execute();
    }

    final elapsedTime = DateTime.now().difference(startTime).inSeconds;
    log.finest('Background task $task completed in $elapsedTime seconds');
    return Future.value(true);
  } catch (e) {
    log.shout('Background task $task failed: $e');
    return Future.value(false);
  }
}
