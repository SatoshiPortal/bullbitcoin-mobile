import 'package:bb_mobile/core/background_tasks/tasks.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:get_it/get_it.dart';
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

  await Bull.initLogs(background: true);
  // Note: `Report.init` is intentionally NOT called here. The BG isolate
  // has its own Dart-side Sentry hub but the native plugin (Sentry
  // Android / iOS) is a process-level singleton. Calling
  // `SentryFlutter.init` again from the BG isolate would re-init the
  // native SDK and stomp the main isolate's crash-handler config when
  // both isolates are alive (foreground app + BG task firing). The
  // trade-off: BG-task failures are captured to the on-disk TSV log
  // only; they don't reach Sentry. If/when we need BG observability,
  // switch to envelope-forwarding (write events to a queue here, ship
  // them next time the main isolate boots).
  await LibLwk.init();

  try {
    final driftIsolate = await SqliteDatabase.createIsolateWithSpawn();
    final sqlite = SqliteDatabase(
      await driftIsolate.connect(singleClientMode: true),
    );
    final locator = GetIt.asNewInstance();
    await AppLocator.setup(locator, sqlite);

    final syncWalletUsecase = locator<SyncWalletUsecase>();
    final getWalletsUsecase = locator<GetWalletsUsecase>();
    final restartSwapWatcherUsecase = locator<RestartSwapWatcherUsecase>();

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
        if (wallets.isEmpty) {
          log.warning('No wallets to sync');
        } else {
          await restartSwapWatcherUsecase.execute();
        }
      case BackgroundTask.logsPrune:
        await log.prune();
    }

    final elapsedTime = DateTime.now().difference(startTime).inSeconds;
    log.config('Background task $task completed in $elapsedTime seconds');
    return Future.value(true);
  } catch (e) {
    log.severe(
      message: 'Background task $task failed',
      error: e,
      trace: StackTrace.current,
    );
    return Future.value(false);
  }
}
