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

/// Schedules the periodic background tasks and removes the obsolete swap task.
Future<void> registerBackgroundTasks() async {
  final adapter = BackgroundTaskWorkmanagerAdapter();
  await adapter.initialize(backgroundTasksHandler);
  await adapter.cancelByUniqueName(BackgroundTask.swapsSync.id);
  await adapter.registerPeriodicTask(
    uniqueName: BackgroundTask.bitcoinSync.id,
    taskName: BackgroundTask.bitcoinSync.name,
    requiresNetwork: true,
  );
  await adapter.registerPeriodicTask(
    uniqueName: BackgroundTask.liquidSync.id,
    taskName: BackgroundTask.liquidSync.name,
    requiresNetwork: true,
  );
  await adapter.registerPeriodicTask(
    uniqueName: BackgroundTask.logsPrune.id,
    taskName: BackgroundTask.logsPrune.name,
    frequency: const Duration(days: 1),
  );
}

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
  await initFlutterRustBridgeDependencies();

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

  final driftIsolate = await SqliteDatabase.createIsolateWithSpawn();
  final sqlite = SqliteDatabase(
    await driftIsolate.connect(singleClientMode: true),
  );
  final headless = GetIt.asNewInstance();
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
  final outbox = SqliteNotificationOutbox(
    databasePath: p.join(bullDirectory.path, notificationOutboxFilename),
  );
  final syncQueue = SqliteWalletSyncJobQueue(
    databasePath: p.join(
      bullDirectory.path,
      'wallet_transaction_sync_queue.sqlite',
    ),
  );
  final localized = await _notificationLocalization(headless);
  final notifications = NotificationsFacade(
    gateway: FlutterLocalNotificationGateway(
      channelId: paymentNotificationChannelId,
      channelName: localized.receivePaymentReceived,
      androidIconResource: androidNotificationIconResource,
    ),
    outbox: outbox,
  );
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
    bitcoinSync: () => WalletTransactionSyncBackgroundTask(
      notifications: notifications,
      jobs: jobs,
      queue: syncQueue,
      copy: copy,
      maxConcurrentJobs: _backgroundWalletSyncConcurrency,
    ).execute(chain: 'bitcoin'),
    liquidSync: () => WalletTransactionSyncBackgroundTask(
      notifications: notifications,
      jobs: jobs,
      queue: syncQueue,
      copy: copy,
      maxConcurrentJobs: _backgroundWalletSyncConcurrency,
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
