import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/core/electrum/adapters/drift_electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/adapters/drift_electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/adapters/electrum_servers_adapter.dart';
import 'package:bb_mobile/core/electrum/adapters/electrum_tor_session_adapter.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_settings_storage_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/electrum_settings/data/wallet_connection_policy_impl.dart';
import 'package:bb_mobile/features/wallet/data/background_wallet_sync_impl.dart';
import 'package:bb_mobile/features/wallet/data/payment_notifications.dart';
import 'package:bb_mobile/features/wallet/data/wallet_catalog_port_impl.dart';
import 'package:bb_mobile/features/wallet/data/wallet_payment_observer.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_tor/tor.dart';
import 'package:bull_tor/tor_adapter.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:transaction_sync/write.dart';

/// Task-specific composition; deliberately never constructs the app locator.
Future<BackgroundTaskRunner> bootstrapBackgroundRunner(
  BackgroundTask task, {
  required Stopwatch clock,
}) async {
  if (!backgroundSyncAvailable) {
    return BackgroundTaskRunner(
      logger: LoggerBackgroundTaskLogger(log),
      handlers: const {},
    );
  }
  final documents = await getApplicationDocumentsDirectory();
  await initializeLogging(directory: documents, background: true);
  final logger = LoggerBackgroundTaskLogger(log);
  return BackgroundTasksLocator.setup(
    task: task,
    logger: logger,
    tasks: {
      BackgroundTask.logsPrune: (resources) async => () async {
        await log.prune();
        return const BackgroundTaskExecutionResult.success();
      },
      BackgroundTask.walletsSync: (resources) async {
        if (!await SqliteDatabase.isAtCurrentSchema()) {
          log.fine('Background wallet task deferred: schema not current');
          return () async => const BackgroundTaskExecutionResult.success();
        }
        final sqlite = SqliteDatabase();
        resources.onClose(sqlite.close);
        final settings = SettingsRepository(
          settingsDatasource: SettingsDatasource(sqlite: sqlite),
        );
        resources.onClose(settings.close);
        final preferences = await settings.fetch();
        final torLocator = GetIt.asNewInstance();
        resources.onClose(torLocator.reset);
        await TorLocator.registerDatasources(torLocator);
        TorLocator.registerRepositories(
          torLocator,
          initialMode: preferences.torTransportMode,
          lastSuccessfulTransport: preferences.lastSuccessfulTorTransport,
        );
        TorLocator.registerUsecases(torLocator);
        final tor = torLocator<Tor>();
        resources.onClose(tor.dispose);
        final connections = WalletConnectionPolicyImpl(
          ElectrumServersAdapter(
            serverRepository: DriftElectrumServerRepository(
              electrumServerStorageDatasource: ElectrumServerStorageDatasource(
                sqlite: sqlite,
              ),
            ),
            settingsRepository: DriftElectrumSettingsRepository(
              electrumSettingsStorageDatasource:
                  ElectrumSettingsStorageDatasource(sqlite: sqlite),
            ),
            appSettingsRepository: settings,
            torSessionPort: ElectrumTorSessionAdapter(() => tor),
          ),
        );
        final catalog = WalletCatalogPortImpl(
          WalletMetadataDatasource(sqlite: sqlite),
        );
        final revisions = RevisionStore(writerMetadataPath(documents.path));
        resources.onClose(revisions.close);
        final queue = SqliteWalletSyncJobQueue(
          databasePath: p.join(
            documents.path,
            'wallet_transaction_sync_queue.sqlite',
          ),
        );
        resources.onClose(queue.close);
        final outbox = PaymentNotifications.openOutbox(documents.path);
        resources.onClose(outbox.dispose);
        final notifications = PaymentNotifications.create(
          outbox,
          preferences.language,
        );
        final initialized = await notifications.initialize();
        if (initialized is Err) throw const _NotificationStartupFailure();
        final catalogResult = await catalog.list();
        final descriptors = switch (catalogResult) {
          Ok(:final value) => value,
          Err() => throw const _CatalogStartupFailure(),
        };
        final sync = ElectrumSync(
          connections: connections,
          documentsDirectory: () async => documents.path,
        );
        final handler = WalletTransactionSyncBackgroundTask(
          writer: BackgroundWalletSyncImpl(
            catalog,
            sync,
            WalletPaymentObserver(() async => notifications, () => false),
          ),
          revisions: revisions,
          keys: descriptors.map((descriptor) => descriptor.key),
          queue: queue,
          notifications: notifications,
          copy: PaymentNotifications.copy(preferences.language),
          runBudget: backgroundRunBudget,
        );
        return () => handler.executeAll(clock: clock);
      },
    },
  );
}

final class _NotificationStartupFailure implements Exception {
  const _NotificationStartupFailure();
}

final class _CatalogStartupFailure implements Exception {
  const _CatalogStartupFailure();
}
