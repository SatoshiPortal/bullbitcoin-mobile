import 'package:bb_mobile/core/background_tasks/tasks.dart';
import 'package:bb_mobile/core/notifications/notifications_service.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
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

  await Bull.initLogs();
  await LibLwk.init();

  try {
    final driftIsolate = await SqliteDatabase.createIsolateWithSpawn();
    final sqlite = SqliteDatabase(
      await driftIsolate.connect(singleClientMode: true),
    );
    final locator = GetIt.asNewInstance();
    await AppLocator.setup(locator, sqlite);

    final backgroundTask = BackgroundTask.fromName(task);

    switch (backgroundTask) {
      case BackgroundTask.bitcoinSync:
      case BackgroundTask.liquidSync:
        // Intentionally disabled until issue #1891 (LWK DB race on concurrent
        // sync) lands a fix. Re-enabling these without the mutex can corrupt
        // the LWK DB and block app startup. See plan doc for details.
        log.info('Background task $task skipped (disabled pending #1891)');
      case BackgroundTask.swapsSync:
        await _runSwapsNotifyPass(locator);
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

/// Notify-only pass for Boltz swaps. Does NOT touch any wallet (BDK/LWK) code —
/// only reads persisted swap state, pokes the Boltz WebSocket for fresh status,
/// and fires a local notification for any swap that still requires user action.
///
/// This is the safe counterpart to full background claims, which would need
/// wallet access and risk reintroducing the LWK concurrency bug (#1891).
Future<void> _runSwapsNotifyPass(GetIt locator) async {
  final notifications = locator.get<NotificationsService>();
  await notifications.init();

  final repos = [
    locator.get<BoltzSwapRepository>(
      instanceName:
          LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
    ),
    locator.get<BoltzSwapRepository>(
      instanceName:
          LocatorInstanceNameConstants.boltzTestnetSwapRepositoryInstanceName,
    ),
  ];

  final initialOngoingPerRepo = <List<Swap>>[];
  for (final repo in repos) {
    initialOngoingPerRepo.add(await repo.getOngoingSwaps());
  }
  final allInitial = initialOngoingPerRepo.expand((s) => s).toList();
  if (allInitial.isEmpty) {
    log.fine('swapsSync: no ongoing swaps');
    return;
  }

  // Ask Boltz for the current status of each ongoing swap. The WebSocket
  // replies with current state on subscribe, and _processWebSocketEvent in
  // BoltzDatasource updates persisted SwapModel rows — no wallet code runs.
  for (var i = 0; i < repos.length; i++) {
    final swaps = initialOngoingPerRepo[i];
    if (swaps.isEmpty) continue;
    repos[i].subscribeToSwaps(swaps.map((s) => s.id).toList());
  }

  // Give the WebSocket round-trip + 2s debounce in _initializeBoltzWebSocket
  // time to flush state updates into storage.
  await Future<void>.delayed(const Duration(seconds: 10));

  final toNotify = <Swap>[];
  for (final repo in repos) {
    final latest = await repo.getOngoingSwaps();
    toNotify.addAll(latest.where((s) => s.requiresAction));
  }

  if (toNotify.isEmpty) {
    log.fine('swapsSync: no swaps require user action');
    return;
  }

  for (final swap in toNotify) {
    await notifications.showSwapNeedsAttention(
      swapId: swap.id,
      walletId: swap.walletId,
      title: _titleFor(swap),
      body: _bodyFor(swap),
    );
  }
  log.info('swapsSync: notified ${toNotify.length} swap(s) needing action');
}

String _titleFor(Swap swap) {
  switch (swap.status) {
    case SwapStatus.claimable:
      return 'Swap ready to claim';
    case SwapStatus.refundable:
      return 'Swap ready to refund';
    case SwapStatus.canCoop:
      return 'Swap needs cooperative close';
    case SwapStatus.failed:
      return 'Swap failed — action needed';
    default:
      return 'Swap needs your attention';
  }
}

String _bodyFor(Swap swap) {
  final action = switch (swap.status) {
    SwapStatus.claimable => 'claim your funds',
    SwapStatus.refundable => 'refund your funds',
    SwapStatus.canCoop => 'complete the cooperative close',
    SwapStatus.failed => 'recover your funds',
    _ => 'complete the swap',
  };
  return 'Open Bull Bitcoin to $action before the swap expires.';
}
