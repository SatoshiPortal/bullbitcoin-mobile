import 'dart:io';

import 'dart:ui' show Locale;

import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/notification_configuration.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/wallet_locator.dart'
    show logWalletCoordination;
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/sync/sync_kind.dart';
import 'package:bb_mobile/core/sync/sync_trigger.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/native_libraries.dart';
import 'package:bb_mobile/payjoin_setup.dart' show payjoinDatabaseFilename;
import 'package:bb_mobile/report_logger_adapter.dart';
import 'package:bull_logger/bull_logger.dart' show initializeLogging, log;
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

// The coordinator keeps one synchronization slot for the foreground, which
// leaves background scans one slot across both tasks: a second worker would
// only wait for it.
const _backgroundWalletSyncConcurrency = 1;

// iOS ends a refresh task after about 30 s, Android a worker after 10 min;
// the budget leaves room for startup and for delivering notifications.
final _backgroundRunBudget = Platform.isIOS
    ? const Duration(seconds: 20)
    : const Duration(minutes: 8);

/// Schedules the periodic background tasks at the interval the user chose,
/// and removes the obsolete swap task. Called at startup and whenever the
/// interval changes; UPDATE keeps an unchanged schedule's timing.
Future<void> registerBackgroundTasks() async {
  final mobile = Platform.isAndroid || Platform.isIOS;
  final adapter = BackgroundTaskWorkmanagerAdapter(
    scheduler: mobile ? null : _desktopScheduler,
  );
  final interval = await const SharedPreferencesBackgroundSyncIntervalStore()
      .read();
  await adapter.initialize(backgroundTasksHandler);
  for (final obsolete in [
    BackgroundTask.swapsSync,
    BackgroundTask.bitcoinSync,
    BackgroundTask.liquidSync,
  ]) {
    await adapter.cancelByUniqueName(obsolete.id);
  }
  final frequency = interval.frequency;
  if (frequency == null) {
    await adapter.cancelByUniqueName(BackgroundTask.walletsSync.id);
  } else {
    await adapter.registerPeriodicTask(
      uniqueName: BackgroundTask.walletsSync.id,
      taskName: BackgroundTask.walletsSync.name,
      requiresNetwork: true,
      frequency: frequency,
      // iOS ignores the frequency: the delay is its "not before" hint. The
      // plugin (workmanager_apple 0.9.11) captures the delay when it first
      // registers its launch handler in a process, so a changed interval is
      // fully applied from the next app start.
      initialDelay: Platform.isIOS ? frequency : null,
    );
  }
  if (mobile) {
    await adapter.registerPeriodicTask(
      uniqueName: BackgroundTask.logsPrune.id,
      taskName: BackgroundTask.logsPrune.name,
      frequency: const Duration(days: 1),
    );
  }
  log.config('Background sync interval applied=${interval.name}');
}

/// Desktop has no headless engine: while the app runs, the chosen interval
/// drives the app's own sync of both chains.
final _desktopScheduler = TimerBackgroundTaskScheduler(
  onTick: (_) => locator<SyncCoordinator>().sync(
    only: {SyncKind.bitcoin, SyncKind.liquid},
    trigger: SyncTrigger.scheduled,
  ),
);

@pragma('vm:entry-point')
void backgroundTasksHandler() {
  runWorkmanagerTaskDispatcher(_bootstrapBackgroundRunner);
}

Future<BackgroundTaskRunner> _bootstrapBackgroundRunner() async {
  final bullDirectory = await getApplicationDocumentsDirectory();
  await initializeLogging(
    directory: bullDirectory,
    background: true,
    reporter: const ReportLoggerAdapter(),
  );
  // The dispatcher turns a bootstrap exception into a retry without a trace,
  // so the failing stage is logged here before it propagates.
  final clock = Stopwatch()..start();
  var stage = 'native';
  try {
    return await _buildBackgroundRunner(bullDirectory, (next) => stage = next);
  } catch (error) {
    log.warning(
      'Background task bootstrap failed stage=$stage '
      'error=${error.runtimeType} elapsed_ms=${clock.elapsedMilliseconds}',
    );
    // The engine is torn down as soon as the task returns.
    await log.flush();
    rethrow;
  }
}

Future<BackgroundTaskRunner> _buildBackgroundRunner(
  Directory bullDirectory,
  void Function(String) enter,
) async {
  await initFlutterRustBridgeDependencies();

  enter('schema');
  // A schedule left by an older release can fire while the updated app is
  // starting. Opening the database here would run the pending migrations on a
  // second connection, concurrently with the app's (#3045). Only the app
  // migrates: until it has, every task is a successful no-op.
  if (!await SqliteDatabase.isAtCurrentSchema()) {
    log.fine('Background task skipped: database not migrated yet');
    return BackgroundTaskRunner(
      logger: LoggerBackgroundTaskLogger(log),
      handlers: const {},
    );
  }

  enter('database');
  final driftIsolate = await SqliteDatabase.createIsolateWithSpawn();
  final sqlite = SqliteDatabase(
    await driftIsolate.connect(singleClientMode: true),
  );
  final headless = GetIt.asNewInstance();
  enter('locator');
  await AppLocator.setup(
    headless,
    sqlite,
    payjoinDatabasePath: p.join(bullDirectory.path, payjoinDatabaseFilename),
    startPayjoinRecovery: false,
    startOrderSwapWatcher: false,
    // The watcher would run an unattended swap signed with the seed.
    startAutoswapWatcher: false,
  );

  final metadata = headless<WalletMetadataDatasource>();
  final coordination = headless<WalletSourceOperationCoordinator>();
  final syncMetadata = headless<WalletSyncMetadataPort>();
  enter('outbox');
  final outbox = SqliteNotificationOutbox(
    databasePath: p.join(bullDirectory.path, notificationOutboxFilename),
  );
  enter('queue');
  final syncQueue = SqliteWalletSyncJobQueue(
    databasePath: p.join(
      bullDirectory.path,
      'wallet_transaction_sync_queue.sqlite',
    ),
  );
  enter('localization');
  final localized = await _notificationLocalization(headless);
  final notifications = NotificationsFacade(
    gateway: FlutterLocalNotificationGateway(
      channelId: paymentNotificationChannelId,
      channelName: localized.receivePaymentReceived,
      androidIconResource: androidNotificationIconResource,
    ),
    outbox: outbox,
  );
  enter('notifications');
  await _initializeNotifications(notifications);

  final bdk = WalletTransactionSyncFacade.bdkElectrum(
    metadata: syncMetadata,
    coordinator: coordination,
    logSink: logWalletCoordination,
  );
  final lwk = WalletTransactionSyncFacade.lwkElectrum(
    metadata: syncMetadata,
    coordinator: coordination,
    logSink: logWalletCoordination,
  );
  NotificationCopy copy(int count, String chain) => (
    title: localized.receivePaymentReceived,
    body: count == 1
        ? chain == 'liquid'
              ? localized.backgroundNotificationLiquidSingular
              : localized.backgroundNotificationBitcoinSingular
        : localized.backgroundNotificationTransactionsPlural(count),
  );
  enter('wallets');
  final wallets = await metadata.fetchAll();
  final jobs = <WalletTransactionSyncBackgroundJob>[];
  for (final wallet in wallets) {
    final model = WalletModel.fromMetadata(wallet);
    final chain = wallet.isLiquid ? 'liquid' : 'bitcoin';
    final network = wallet.isTestnet ? 'testnet' : 'mainnet';
    final key = WalletNetworkKey(wallet.id, chain, network);
    jobs.add(
      WalletTransactionSyncBackgroundJob(
        key: key,
        queueRevision: 'legacy-electrum-v1',
        synchronize: () => _synchronize(
          model: model,
          key: key,
          facade: wallet.isLiquid ? lwk : bdk,
          servers: headless<ElectrumServersPort>(),
        ),
      ),
    );
  }

  return BackgroundTaskRunner.compatibility(
    logger: LoggerBackgroundTaskLogger(log),
    walletsSync: () => WalletTransactionSyncBackgroundTask(
      notifications: notifications,
      jobs: jobs,
      queue: syncQueue,
      copy: copy,
      maxConcurrentJobs: _backgroundWalletSyncConcurrency,
      runBudget: _backgroundRunBudget,
    ).executeAll(),
    bitcoinSync: () => WalletTransactionSyncBackgroundTask(
      notifications: notifications,
      jobs: jobs,
      queue: syncQueue,
      copy: copy,
      maxConcurrentJobs: _backgroundWalletSyncConcurrency,
      runBudget: _backgroundRunBudget,
    ).execute(chain: 'bitcoin'),
    liquidSync: () => WalletTransactionSyncBackgroundTask(
      notifications: notifications,
      jobs: jobs,
      queue: syncQueue,
      copy: copy,
      maxConcurrentJobs: _backgroundWalletSyncConcurrency,
      runBudget: _backgroundRunBudget,
    ).execute(chain: 'liquid'),
    pruneLogs: log.prune,
    onFinished: () => _runAllCleanups([
      bdk.dispose,
      lwk.dispose,
      headless.reset,
      () async => outbox.dispose(),
      syncQueue.close,
      sqlite.close,
    ]),
  );
}

Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
_synchronize({
  required WalletModel model,
  required WalletNetworkKey key,
  required WalletTransactionSyncFacade facade,
  required ElectrumServersPort servers,
}) async {
  final network = ElectrumServerNetwork.fromEnvironment(
    isTestnet: model.isTestnet,
    isLiquid: model is PublicLwkWalletModel,
  );
  try {
    return await servers.runWithFallback(
      network: network,
      isTransient: (error) => error is _TransientBackgroundSync,
      operation: (connection) async {
        final configuration = model is PublicBdkWalletModel
            ? BdkElectrumConfiguration(
                externalPublicDescriptor: model.externalDescriptor,
                internalPublicDescriptor: model.internalDescriptor,
                isTestnet: model.isTestnet,
                electrumUrls: [connection.url],
                stopGap: connection.stopGap,
                validateDomain: connection.validateDomain,
                databaseFilePath: p.join(
                  (await getApplicationDocumentsDirectory()).path,
                  '${model.hexId}_bdk_dart',
                ),
                socks5: connection.socks5,
                timeout: connection.effectiveTimeout,
                retry: connection.retry,
              )
            : LwkElectrumConfiguration(
                confidentialPublicDescriptor:
                    (model as PublicLwkWalletModel).combinedCtDescriptor,
                isTestnet: model.isTestnet,
                electrumUrls: [connection.url],
                validateDomain: connection.validateDomain,
                databaseRootPath: p.join(
                  (await getApplicationDocumentsDirectory()).path,
                  model.hexId,
                ),
                timeout: connection.effectiveTimeout,
                stopAtIndex: connection.stopGap,
              );
        final registration = WalletSourceRegistration.withFingerprint(
          key: key,
          sourceKind: model is PublicLwkWalletModel
              ? 'lwk_electrum'
              : 'bdk_electrum',
          configuration: configuration,
        );
        final result = await facade.synchronizeWallet(
          SynchronizeWalletRequest(
            registration,
            priority: WalletOperationPriority.background,
            allowInitialScan: false,
          ),
        );
        if (result case Err(:final failure)
            when failure is SourceFailure &&
                failure.reason == SourceFailureReason.unavailable) {
          throw const _TransientBackgroundSync();
        }
        return result;
      },
    );
  } on Exception {
    return const Err(SourceFailure(SourceFailureReason.unavailable));
  }
}

Future<void> _initializeNotifications(NotificationsFacade notifications) async {
  final result = await notifications.initialize();
  if (result case Err()) {
    log.warning('Background notification initialization failed');
  }
}

Future<AppLocalizations> _notificationLocalization(GetIt headless) async {
  final settings = await headless<SettingsRepository>().fetch();
  final locale = settings.language?.locale ?? const Locale('en');
  return AppLocalizations.delegate.load(locale);
}

final class _TransientBackgroundSync implements Exception {
  const _TransientBackgroundSync();
}

Future<void> _runAllCleanups(List<Future<void> Function()> cleanups) async {
  var failed = false;
  for (final cleanup in cleanups) {
    try {
      await cleanup();
    } catch (_) {
      failed = true;
    }
  }
  if (failed) throw const _BackgroundCleanupFailure();
}

final class _BackgroundCleanupFailure implements Exception {
  const _BackgroundCleanupFailure();
}
