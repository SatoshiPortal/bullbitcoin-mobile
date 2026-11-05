import 'package:wallet/wallet.dart';
import 'dart:io';

import 'dart:ui' show Locale;

import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/notification_adapters.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/wallet_setup.dart' show logWalletCoordination;
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/native_libraries.dart';
import 'package:bb_mobile/payjoin_setup.dart' show payjoinDatabaseFilename;
import 'package:bb_mobile/report_logger_adapter.dart';
import 'package:bb_mobile/sync_runtime_adapters.dart';
import 'package:bull_logger/bull_logger.dart' show initializeLogging, log;
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// Builds the minimal headless graph a WorkManager task runs on.
Future<BackgroundTaskRunner> bootstrapBackgroundRunner() async {
  // The run budget counts from here: the platform's limit includes startup.
  final clock = Stopwatch()..start();
  final bullDirectory = await getApplicationDocumentsDirectory();
  await initializeLogging(
    directory: bullDirectory,
    background: true,
    reporter: const ReportLoggerAdapter(),
  );
  // The dispatcher turns a bootstrap exception into a retry without a trace,
  // so the failing stage is logged here before it propagates.
  var stage = 'native';
  try {
    return await _buildBackgroundRunner(
      bullDirectory,
      (next) => stage = next,
      clock,
    );
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
  Stopwatch clock,
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

  final metadata = headless<WalletCatalogPort>();
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

  final bdk = WalletTransactionSyncFacade(
    metadata: syncMetadata,
    coordinator: coordination,
    source: WalletLocator.bdkElectrum(logSink: logWalletCoordination),
  );
  final lwk = WalletTransactionSyncFacade(
    metadata: syncMetadata,
    coordinator: coordination,
    source: WalletLocator.lwkElectrum(logSink: logWalletCoordination),
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
        synchronize: () => synchronizeWalletInBackground(
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
      maxConcurrentJobs: backgroundWalletSyncConcurrency,
      runBudget: backgroundRunBudget,
    ).executeAll(clock: clock),
    bitcoinSync: () => WalletTransactionSyncBackgroundTask(
      notifications: notifications,
      jobs: jobs,
      queue: syncQueue,
      copy: copy,
      maxConcurrentJobs: backgroundWalletSyncConcurrency,
      runBudget: backgroundRunBudget,
    ).execute(chain: 'bitcoin'),
    liquidSync: () => WalletTransactionSyncBackgroundTask(
      notifications: notifications,
      jobs: jobs,
      queue: syncQueue,
      copy: copy,
      maxConcurrentJobs: backgroundWalletSyncConcurrency,
      runBudget: backgroundRunBudget,
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
