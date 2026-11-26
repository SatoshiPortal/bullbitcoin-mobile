import 'package:preferences/preferences.dart'
    show Language, Preferences, PreferencesFailure;

import 'dart:io';

import '../background_tasks.dart';

import 'package:legacy_storage/app_database.dart' show SqliteDatabase;

import '../native_sync.dart';

import 'package:notifications/notifications.dart';

import 'wallet_payment_observer.dart';

import 'package:bull_logger/bull_logger.dart';
import 'package:bull_tor/tor.dart';
import 'package:bull_tor/tor_adapter.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart' show BackgroundWalletDescriptors;
import 'package:sync/inventory.dart';
import 'package:sync/write.dart';
import 'package:electrum/electrum.dart';
import 'package:electrum/setup.dart';

const _queueFilename = 'wallet_transaction_sync_queue.sqlite';

/// Foreground only, and the only creator of the queue and of the
/// notification store, which the background task opens without creating.
Future<void> prepareBackgroundWalletStores({
  required Future<NotificationsFacade> Function() openNotifications,
}) async {
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
    await openNotifications();
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
  required File preferencesFile,
  required BackgroundSyncIntervalRepository intervals,
  required Future<NotificationsFacade?> Function(
    String documents,
    Language? language,
    BackgroundTaskResources resources,
  )
  openNotifications,
  required ({String title, String body}) Function(int) Function(Language?)
  paymentCopy,
}) async {
  final admission = resources.storageAdmission;
  if (admission == null) {
    return () async => const BackgroundTaskExecutionResult.retry();
  }
  if (!await SqliteDatabase.isAtCurrentSchema()) {
    log.fine('Background wallet task deferred: schema not current');
    return () async => const BackgroundTaskExecutionResult.retry();
  }
  final openedPreferences = await Preferences.open(
    file: preferencesFile,
    admission: admission,
  );
  if (openedPreferences case Err()) {
    return () async => const BackgroundTaskExecutionResult.retry();
  }
  final settings =
      (openedPreferences as Ok<Preferences, PreferencesFailure>).value;
  resources.onClose(settings.close);
  final preferences = (await settings.fetch()).fold(
    (value) => value,
    (failure) => throw Exception('Preferences read failed'),
  );
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
  final support = await getApplicationSupportDirectory();
  final opened = await Electrum.open(
    file: File(p.join(support.path, 'databases', 'electrum.sqlite')),
    admission: admission,
    readPreferences: settings.readConnectionPreferences,
    tor: () => tor,
  );
  if (opened case Err()) {
    return () async => const BackgroundTaskExecutionResult.retry();
  }
  final connections =
      (opened as Ok<Electrum, ElectrumFailure>).value.walletConnections;
  final openedDescriptors = await BackgroundWalletDescriptors.open(
    file: File(p.join(support.path, 'databases', 'secrets.sqlite')),
    admission: admission,
  );
  final descriptorsStore = switch (openedDescriptors) {
    Ok(:final value) => value,
    Err() => null,
  };
  if (descriptorsStore == null) {
    return () async => const BackgroundTaskExecutionResult.retry();
  }
  resources.onClose(descriptorsStore.close);
  final catalog = SecretsWalletCatalog.background(descriptorsStore);
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
  final notifications = await openNotifications(
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
            copy: paymentCopy(preferences.language),
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
