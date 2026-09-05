import 'dart:ui' show Locale;

import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/notification_configuration.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:bull_logger/bull_logger.dart' show log;
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

const _backgroundWalletSyncConcurrency = 2;

@pragma('vm:entry-point')
void backgroundTasksHandler() {
  runWorkmanagerTaskDispatcher(_bootstrapBackgroundRunner);
}

Future<BackgroundTaskRunner> _bootstrapBackgroundRunner() async {
  await Bull.initLogs(background: true);
  await Bull.initFlutterRustBridgeDependencies();

  final driftIsolate = await SqliteDatabase.createIsolateWithSpawn();
  final sqlite = SqliteDatabase(
    await driftIsolate.connect(singleClientMode: true),
  );
  final headless = GetIt.asNewInstance();
  await AppLocator.setup(
    headless,
    sqlite,
    startPayjoinRecovery: false,
    startOrderSwapWatcher: false,
  );

  final documents = await getApplicationDocumentsDirectory();
  final metadata = headless<WalletMetadataDatasource>();
  final coordination = headless<WalletSourceOperationCoordinator>();
  final syncMetadata = headless<WalletSyncMetadataPort>();
  final outbox = SqliteNotificationOutbox(
    databasePath: path.join(documents.path, 'notification_outbox.sqlite'),
  );
  final syncQueue = SqliteWalletSyncJobQueue(
    databasePath: path.join(
      documents.path,
      'wallet_transaction_sync_queue.sqlite',
    ),
  );
  final localized = await _notificationLocalization(headless);
  final notifications = NotificationsFacade(
    gateway: FlutterLocalNotificationGateway(
      channelId: 'bull_wallet_payments',
      channelName: localized.receivePaymentReceived,
      androidIconResource: androidNotificationIconResource,
    ),
    outbox: outbox,
  );
  await _initializeNotifications(notifications);

  final bdk = WalletTransactionSyncFacade.bdkElectrum(
    metadata: syncMetadata,
    coordinator: coordination,
  );
  final lwk = WalletTransactionSyncFacade.lwkElectrum(
    metadata: syncMetadata,
    coordinator: coordination,
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
                databaseFilePath: path.join(
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
                databaseRootPath: path.join(
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
