import 'dart:async';
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
import 'package:boltz/boltz.dart' as boltz_pkg;
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

/// Notify-only pass for Boltz swaps. Strictly read-only with respect to the
/// shared app SQLite DB — we read ongoing swaps, open short-lived Boltz
/// WebSocket connections of our own to fetch fresh status in memory, and
/// fire local notifications. Never touches LWK/BDK, never writes to the
/// swaps table.
///
/// The stricter read-only stance (vs. going through `BoltzSwapRepository`,
/// which would trigger `_processWebSocketEvent` → SQLite writes) matches
/// the architectural invariant flagged by project maintainers: background
/// tasks should not collide with the app on shared databases. See #1891
/// for the broader context on sync-in-background.
Future<void> _runSwapsNotifyPass(GetIt locator) async {
  final notifications = locator.get<NotificationsService>();
  await notifications.init();
  final loc = await _loadLocalizations(locator);

  // Partition swaps by network using the two repo instances (each already
  // filters its storage query by isTestnet).
  final mainnetRepo = locator.get<BoltzSwapRepository>(
    instanceName: LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
  );
  final testnetRepo = locator.get<BoltzSwapRepository>(
    instanceName:
        LocatorInstanceNameConstants.boltzTestnetSwapRepositoryInstanceName,
  );

  final mainnetSwaps = await _collectCandidateSwaps(mainnetRepo);
  final testnetSwaps = await _collectCandidateSwaps(testnetRepo);
  if (mainnetSwaps.isEmpty && testnetSwaps.isEmpty) {
    log.fine('swapsSync: no candidate swaps');
    return;
  }

  // Open own WebSockets per network, subscribe for status, collect in memory.
  // No writes to any shared datastore happen from these.
  final freshStatuses = <String, boltz_pkg.SwapStatus>{};
  final results = await Future.wait([
    _collectFreshBoltzStatuses(
      baseUrl: ApiServiceConstants.boltzMainnetUrlPath,
      swapIds: mainnetSwaps.map((s) => s.id).toList(),
      timeout: const Duration(seconds: 8),
    ),
    _collectFreshBoltzStatuses(
      baseUrl: ApiServiceConstants.boltzTestnetUrlPath,
      swapIds: testnetSwaps.map((s) => s.id).toList(),
      timeout: const Duration(seconds: 8),
    ),
  ]);
  freshStatuses.addAll(results[0]);
  freshStatuses.addAll(results[1]);

  var notified = 0;
  for (final swap in [...mainnetSwaps, ...testnetSwaps]) {
    if (!_requiresActionNow(swap, freshStatuses[swap.id])) continue;
    final walletId = _notificationWalletId(swap);
    if (walletId == null) continue; // external chain swap — no in-app claim
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

/// Union of `getOngoingSwaps()` (pending/paid/canCoop/claimable/refundable)
/// and `getSwapsNeedingUserAction()` (adds failed LnSendSwaps that still need
/// an on-chain refund). Deduped by id.
Future<List<Swap>> _collectCandidateSwaps(BoltzSwapRepository repo) async {
  final ongoing = await repo.getOngoingSwaps();
  final needing = await repo.getSwapsNeedingUserAction();
  final byId = <String, Swap>{};
  for (final s in [...ongoing, ...needing]) {
    byId[s.id] = s;
  }
  return byId.values.toList();
}

/// Opens an ephemeral Boltz WebSocket, subscribes to the given swap ids,
/// collects the latest status per id for up to [timeout], then disposes.
/// Returns a map of swap id → latest Boltz status observed.
///
/// Deliberately does NOT go through `BoltzDatasource` / `BoltzSwapRepository`
/// because those persist status updates back to SQLite via
/// `_processWebSocketEvent`. This pass must be zero-write.
Future<Map<String, boltz_pkg.SwapStatus>> _collectFreshBoltzStatuses({
  required String baseUrl,
  required List<String> swapIds,
  required Duration timeout,
}) async {
  if (swapIds.isEmpty) return {};
  final latest = <String, boltz_pkg.SwapStatus>{};
  final ws = boltz_pkg.BoltzWebSocket.create(baseUrl);
  StreamSubscription<boltz_pkg.SwapStreamStatus>? sub;
  try {
    sub = ws.stream.listen(
      (event) {
        if (event.id.isEmpty) return; // global error frames have empty id
        latest[event.id] = event.status;
      },
      onError: (Object e) {
        log.warning(
          'Boltz WS error during background status pull ($baseUrl): $e',
        );
      },
    );
    ws.subscribe(swapIds);
    await Future<void>.delayed(timeout);
  } catch (e) {
    log.warning('Boltz WS setup failed ($baseUrl): $e');
  } finally {
    await sub?.cancel();
    try {
      ws.dispose();
    } catch (_) {}
  }
  return latest;
}

/// Decides whether [swap] currently requires user action, combining the
/// persisted state with an optional fresh Boltz status event.
///
/// Invariant: we trust the persisted `requiresAction` first (no round-trip
/// needed when the swap is already known-actionable). If a fresh Boltz
/// status arrived, we also detect transitions into actionable states that
/// haven't been written to storage yet.
bool _requiresActionNow(Swap swap, boltz_pkg.SwapStatus? fresh) {
  if (swap.requiresAction) return true;
  if (fresh == null) return false;
  switch (swap) {
    case LnReceiveSwap s:
      // Reverse swap: claimable once the server-side HTLC is visible.
      final isLiquid = s.type == SwapType.lightningToLiquid;
      if (s.receiveTxid != null) return false;
      if (fresh == boltz_pkg.SwapStatus.invoiceSettled) return true;
      if (isLiquid && fresh == boltz_pkg.SwapStatus.txnMempool) return true;
      if (!isLiquid && fresh == boltz_pkg.SwapStatus.txnConfirmed) return true;
      return false;
    case LnSendSwap s:
      // canCoop as soon as invoice is paid / claim is pending.
      if (fresh == boltz_pkg.SwapStatus.invoicePaid) return true;
      if (fresh == boltz_pkg.SwapStatus.txnClaimPending) return true;
      // Refundable once a failure lands with funds still locked on-chain.
      final canRefund = s.sendTxid != null && s.refundTxid == null;
      if (!canRefund) return false;
      return _isFailureStatus(fresh);
    case ChainSwap s:
      // Claimable once Boltz has locked funds on the user's receive leg.
      final isLiquidTarget = s.type == SwapType.bitcoinToLiquid;
      final claimPending = s.receiveTxid == null;
      if (claimPending &&
          fresh == boltz_pkg.SwapStatus.txnServerMempool &&
          isLiquidTarget) {
        return true;
      }
      if (claimPending && fresh == boltz_pkg.SwapStatus.txnServerConfirmed) {
        return true;
      }
      if (claimPending && fresh == boltz_pkg.SwapStatus.txnClaimed) return true;
      final canRefund = s.sendTxid != null && s.refundTxid == null;
      if (!canRefund) return false;
      return _isFailureStatus(fresh);
  }
}

bool _isFailureStatus(boltz_pkg.SwapStatus fresh) {
  return fresh == boltz_pkg.SwapStatus.invoiceFailedToPay ||
      fresh == boltz_pkg.SwapStatus.txnLockupFailed ||
      fresh == boltz_pkg.SwapStatus.txnFailed ||
      fresh == boltz_pkg.SwapStatus.txnRefunded ||
      fresh == boltz_pkg.SwapStatus.swapExpired ||
      fresh == boltz_pkg.SwapStatus.invoiceExpired ||
      fresh == boltz_pkg.SwapStatus.swapError ||
      fresh == boltz_pkg.SwapStatus.swapRefunded;
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
