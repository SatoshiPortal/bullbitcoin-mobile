import 'dart:ui' show Locale;

import 'package:bb_mobile/core/background_tasks/tasks.dart';
import 'package:bb_mobile/core/notifications/notifications_service.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/generated/l10n/localization.dart';
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
  final loc = await _loadLocalizations(locator);

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

  // `getSwapsNeedingUserAction()` (not `getOngoingSwaps`) also surfaces
  // failed LnSendSwaps — those are excluded from the "ongoing" view but the
  // user still needs to refund their on-chain lockup.
  final toNotify = <Swap>[];
  for (final repo in repos) {
    toNotify.addAll(await repo.getSwapsNeedingUserAction());
  }

  if (toNotify.isEmpty) {
    log.fine('swapsSync: no swaps require user action');
    return;
  }

  var notified = 0;
  for (final swap in toNotify) {
    final walletId = _notificationWalletId(swap);
    if (walletId == null) continue; // external chain swap with no in-app claim
    await notifications.showSwapNeedsAttention(
      swapId: swap.id,
      walletId: walletId,
      title: _titleFor(loc, swap),
      body: _bodyFor(loc, swap),
    );
    notified++;
  }
  log.info('swapsSync: notified $notified swap(s) needing action');
}

/// Picks the wallet whose detail view is most useful for the current swap
/// status. `Swap.walletId` is action-agnostic (always sendWalletId for
/// ChainSwap), which sends the user to the wrong screen on `claimable`
/// chain swaps. For external chain swaps there is no in-app claim path;
/// we return null so the caller skips the notification.
String? _notificationWalletId(Swap swap) {
  if (swap is ChainSwap && swap.status == SwapStatus.claimable) {
    return swap.receiveWalletId; // null for external chain swaps
  }
  return swap.walletId;
}

/// Loads `AppLocalizations` for the user's persisted language. Falls back to
/// English if SettingsRepository can't be reached or the language is unset —
/// English notifications are strictly better than no notifications.
Future<AppLocalizations> _loadLocalizations(GetIt locator) async {
  Locale locale = const Locale('en', 'US');
  try {
    final settings = await locator.get<SettingsRepository>().fetch();
    final language = settings.language;
    if (language != null) {
      locale = language.locale;
    }
  } catch (e) {
    log.warning('Failed to read language from settings: $e');
  }
  return AppLocalizations.delegate.load(locale);
}

String _titleFor(AppLocalizations loc, Swap swap) {
  switch (swap.status) {
    case SwapStatus.claimable:
      return loc.notificationSwapClaimableTitle;
    case SwapStatus.refundable:
      return loc.notificationSwapRefundableTitle;
    case SwapStatus.canCoop:
      return loc.notificationSwapCanCoopTitle;
    case SwapStatus.failed:
      return loc.notificationSwapFailedTitle;
    default:
      return loc.notificationSwapAttentionTitle;
  }
}

String _bodyFor(AppLocalizations loc, Swap swap) {
  switch (swap.status) {
    case SwapStatus.claimable:
      return loc.notificationSwapClaimableBody;
    case SwapStatus.refundable:
      return loc.notificationSwapRefundableBody;
    case SwapStatus.canCoop:
      return loc.notificationSwapCanCoopBody;
    case SwapStatus.failed:
      return loc.notificationSwapFailedBody;
    default:
      return loc.notificationSwapAttentionBody;
  }
}
