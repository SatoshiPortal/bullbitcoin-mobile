import 'dart:io';

import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/features/settings/data/settings_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
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
import 'package:bb_mobile/features/electrum_settings/public/electrum_settings_facade.dart';

const paymentNotificationChannelId = PaymentNotifications.channelId;
const _queueFilename = 'wallet_transaction_sync_queue.sqlite';

/// Foreground only, and the only creator of the queue and of the
/// notification store, which the background task opens without creating.
Future<void> prepareBackgroundWalletStores(GetIt locator) async {
  if (!backgroundSyncAvailable) return;
  final documents = await getApplicationDocumentsDirectory();
  final queue = openForegroundWalletSyncJobQueue(
    p.join(documents.path, _queueFilename),
  );
  switch (queue) {
    case Ok(:final value):
      await value.close();
    case Err(:final failure):
      log.warning(
        'Background queue unavailable category=${failure.runtimeType}',
      );
  }
  try {
    await locator<PaymentNotificationStore>().open();
  } on Exception {
    log.warning('Payment notification store unavailable');
  }
}

/// Opens only what the foreground created, never creating nor migrating it:
/// without its queue, the task is deferred to a later run.
Future<BackgroundTaskHandler> setupBackgroundWalletTask(
  BackgroundTaskResources resources,
  Directory documents,
  Stopwatch clock, {
  required BackgroundSyncIntervalRepository intervals,
}) async {
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
  final connections = createBackgroundWalletConnections(sqlite, settings, tor);
  final catalog = WalletCatalogPortImpl(
    WalletMetadataDatasource(sqlite: sqlite),
  );
  final ExistingStores stores;
  try {
    stores = openExisting(documents.path);
  } on Exception {
    log.fine('Background wallet task deferred: writer metadata unavailable');
    return () async => const BackgroundTaskExecutionResult.success();
  }
  resources.onClose(stores.close);
  final WalletSyncJobQueueRepository queue;
  switch (openBackgroundWalletSyncQueue(documents.path)) {
    case Ok(:final value):
      queue = value;
    case Err():
      log.fine('Background wallet task deferred: queue unavailable');
      return () async => const BackgroundTaskExecutionResult.success();
  }
  resources.onClose(queue.close);
  final notifications = await PaymentNotifications.initializeBackground(
    documents.path,
    preferences.language,
    resources,
  );
  final catalogResult = await catalog.list();
  final descriptors = switch (catalogResult) {
    Ok(:final value) => value,
    Err() => throw const _CatalogStartupFailure(),
  };
  final sync = ElectrumSync(
    connections: connections,
    documentsDirectory: () async => documents.path,
    readRevision: stores.revisions.read,
  );
  final usecase = RunWalletSyncJobsUsecase(
    wallets: BackgroundWalletSyncImpl(
      catalog,
      sync,
      collectIncoming: notifications != null,
    ),
    revisions: stores.revisions,
    keys: descriptors.map((descriptor) => descriptor.key),
    queue: queue,
    intervals: intervals,
    announcements: notifications == null
        ? null
        : WalletPaymentObserver.background(
            () async => notifications,
            copy: PaymentNotifications.copy(preferences.language),
          ),
    logger: LoggerBackgroundTaskLogger(log),
    runBudget: backgroundRunBudget,
  );
  return () => usecase.execute(clock: clock);
}

/// The queue the foreground created; a missing, older or newer one is refused.
Result<WalletSyncJobQueueRepository, BackgroundTasksFailure>
openBackgroundWalletSyncQueue(String documents) =>
    openExistingWalletSyncJobQueue(p.join(documents, _queueFilename));

final class _CatalogStartupFailure implements Exception {
  const _CatalogStartupFailure();
}
