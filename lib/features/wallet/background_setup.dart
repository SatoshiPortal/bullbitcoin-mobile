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
import 'package:primitives/primitives.dart';
import 'package:sync/write.dart';
import 'package:bb_mobile/features/electrum_settings/public/electrum_settings_facade.dart';

const paymentNotificationChannelId = PaymentNotifications.channelId;

Future<BackgroundTaskHandler> setupBackgroundWalletTask(
  BackgroundTaskResources resources,
  Directory documents,
  Stopwatch clock,
) async {
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
  final queue = SqliteWalletSyncJobQueue(
    databasePath: p.join(
      documents.path,
      'wallet_transaction_sync_queue.sqlite',
    ),
  );
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
  final handler = WalletTransactionSyncBackgroundTask(
    writer: BackgroundWalletSyncImpl(
      catalog,
      sync,
      notifications == null
          ? null
          : WalletPaymentObserver(() async => notifications, () => false),
    ),
    revisions: stores.revisions,
    keys: descriptors.map((descriptor) => descriptor.key),
    queue: queue,
    notifications: notifications,
    copy: PaymentNotifications.copy(preferences.language),
    runBudget: backgroundRunBudget,
  );
  return () => handler.executeAll(clock: clock);
}

final class _CatalogStartupFailure implements Exception {
  const _CatalogStartupFailure();
}
