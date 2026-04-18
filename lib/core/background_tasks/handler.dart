import 'dart:async';
import 'dart:ui' show Locale;

import 'package:bb_mobile/core/background_tasks/swap_action_rules.dart';
import 'package:bb_mobile/core/background_tasks/tasks.dart';
import 'package:bb_mobile/core/notifications/notifications_service.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_storage_datasource.dart';
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
/// shared app SQLite DB — we read candidate swaps directly from
/// [BoltzStorageDatasource], open a short-lived Boltz WebSocket of our own to
/// fetch fresh status in memory, and fire local notifications. Never touches
/// LWK/BDK, never writes to the swaps table.
///
/// We deliberately bypass `BoltzSwapRepository` / `BoltzDatasource` here:
/// `BoltzDatasource`'s constructor eagerly opens a persistent WebSocket whose
/// status events write back to SQLite via `_processWebSocketEvent`. Resolving
/// the repository in the background isolate would therefore open an implicit,
/// un-disposed socket alongside our ephemeral one and partially defeat the
/// zero-write invariant. Reading through the storage datasource avoids both.
/// See #1891 for the broader context on sync-in-background.
Future<void> _runSwapsNotifyPass(GetIt locator) async {
  final notifications = locator.get<NotificationsService>();
  await notifications.init();
  final loc = await _loadLocalizations(locator);

  // Only notify for swaps in the user's currently selected environment —
  // GetSwapUsecase also resolves the repo from current settings, so tapping
  // a cross-env notification lands on "swap not found".
  final isTestnet = await _currentEnvironmentIsTestnet(locator);
  final storage = locator.get<BoltzStorageDatasource>();

  final swaps = await _collectCandidateSwaps(storage, isTestnet: isTestnet);
  if (swaps.isEmpty) {
    log.fine('swapsSync: no candidate swaps');
    return;
  }

  // Open own WebSocket for the active network, subscribe for status, collect
  // in memory. No writes to any shared datastore happen from this.
  final freshStatuses = await _collectFreshBoltzStatuses(
    baseUrl: isTestnet
        ? ApiServiceConstants.boltzTestnetUrlPath
        : ApiServiceConstants.boltzMainnetUrlPath,
    swapIds: swaps.map((s) => s.id).toList(),
    timeout: const Duration(seconds: 8),
  );

  var notified = 0;
  for (final swap in swaps) {
    final fresh = freshStatuses[swap.id];
    final effective = effectiveActionableStatus(swap, fresh);
    if (effective == null) continue;
    final walletId = notificationWalletId(swap, effective);
    if (walletId == null) continue; // external chain swap — no in-app claim
    await notifications.showSwapNeedsAttention(
      swapId: swap.id,
      walletId: walletId,
      title: _titleFor(loc, effective),
      body: _bodyFor(loc, effective),
    );
    notified++;
  }
  log.info('swapsSync: notified $notified swap(s) needing action');
}

Future<bool> _currentEnvironmentIsTestnet(GetIt locator) async {
  try {
    final settings = await locator.get<SettingsRepository>().fetch();
    return settings.environment.isTestnet;
  } catch (e) {
    log.warning(
      'swapsSync: could not read environment, defaulting to mainnet: $e',
    );
    return false;
  }
}

/// Candidate swaps for the background notify pass: the union of statuses
/// that imply ongoing activity (pending/paid/canCoop/claimable/refundable
/// plus a couple of completed-but-missing-txid edges) and any swap whose
/// persisted `requiresAction` getter is true. Reads the storage datasource
/// directly to avoid instantiating `BoltzDatasource`, which would open an
/// eager persistent WebSocket.
Future<List<Swap>> _collectCandidateSwaps(
  BoltzStorageDatasource storage, {
  required bool isTestnet,
}) async {
  final models = await storage.fetchAll(isTestnet: isTestnet);
  return models.map((m) => m.toEntity()).where(_isNotifyCandidate).toList();
}

bool _isNotifyCandidate(Swap swap) {
  if (swap.requiresAction) return true;
  switch (swap.status) {
    case SwapStatus.pending:
    case SwapStatus.paid:
    case SwapStatus.canCoop:
    case SwapStatus.claimable:
    case SwapStatus.refundable:
      return true;
    case SwapStatus.completed:
      // Chain/reverse swaps occasionally land at `completed` with no txid
      // recorded — they still need to be polled in case Boltz has a late
      // claim/refund to surface.
      if (swap is ChainSwap) {
        return swap.receiveTxid == null && swap.refundTxid == null;
      }
      if (swap is LnReceiveSwap) {
        return swap.receiveTxid == null;
      }
      return false;
    case SwapStatus.expired:
    case SwapStatus.failed:
      return false;
  }
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

/// Loads `AppLocalizations` for the user's persisted language. Falls back to
/// English if SettingsRepository can't be reached, the language is unset, or
/// the delegate fails to load the chosen locale — English notifications are
/// strictly better than no notifications.
Future<AppLocalizations> _loadLocalizations(GetIt locator) async {
  const fallback = Locale('en', 'US');
  Locale locale = fallback;
  try {
    final settings = await locator.get<SettingsRepository>().fetch();
    final language = settings.language;
    if (language != null) {
      locale = language.locale;
    }
  } catch (e) {
    log.warning('Failed to read language from settings: $e');
  }
  try {
    return await AppLocalizations.delegate.load(locale);
  } catch (e) {
    log.warning(
      'Failed to load AppLocalizations for $locale, falling back: $e',
    );
    return AppLocalizations.delegate.load(fallback);
  }
}

String _titleFor(AppLocalizations loc, SwapStatus effective) {
  switch (effective) {
    case SwapStatus.claimable:
      return loc.notificationSwapClaimableTitle;
    case SwapStatus.refundable:
      return loc.notificationSwapRefundableTitle;
    case SwapStatus.canCoop:
      return loc.notificationSwapCanCoopTitle;
    case SwapStatus.failed:
      return loc.notificationSwapFailedTitle;
    // ignore: no_default_cases
    default:
      return loc.notificationSwapAttentionTitle;
  }
}

String _bodyFor(AppLocalizations loc, SwapStatus effective) {
  switch (effective) {
    case SwapStatus.claimable:
      return loc.notificationSwapClaimableBody;
    case SwapStatus.refundable:
      return loc.notificationSwapRefundableBody;
    case SwapStatus.canCoop:
      return loc.notificationSwapCanCoopBody;
    case SwapStatus.failed:
      return loc.notificationSwapFailedBody;
    // ignore: no_default_cases
    default:
      return loc.notificationSwapAttentionBody;
  }
}
