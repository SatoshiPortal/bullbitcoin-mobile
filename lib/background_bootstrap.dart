import 'dart:io';

import 'package:electrum/migration.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:legacy_storage/coordination.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/storage_owner_manifest.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/wallet/background_setup.dart'
    show setupArkBackgroundTask;
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart'
    show recoverBullDefaultServerUrl;
import 'package:path_provider/path_provider.dart';
import 'package:preferences/migration.dart';

/// Task-specific composition; deliberately never constructs the app locator.
Future<BackgroundTaskRunner> bootstrapBackgroundRunner(
  BackgroundTask task, {
  required Stopwatch clock,
}) async {
  if (!backgroundSyncAvailable && task != BackgroundTask.arkRenewal) {
    return BackgroundTaskRunner(
      logger: LoggerBackgroundTaskLogger(log),
      handlers: const {},
    );
  }
  return bootstrapAdmittedBackgroundRunner(task, clock: clock);
}

/// Runs storage admission after the platform rollout decision.
@visibleForTesting
Future<BackgroundTaskRunner> bootstrapAdmittedBackgroundRunner(
  BackgroundTask task, {
  required Stopwatch clock,
}) async {
  final documents = await getApplicationDocumentsDirectory();
  await initializeLogging(directory: documents, background: true);
  final logger = LoggerBackgroundTaskLogger(log);
  const intervals = SharedPreferencesBackgroundSyncIntervalRepository();
  final support = await getApplicationSupportDirectory();
  final preferencesFile = File('${support.path}/databases/preferences.sqlite');
  final cutover = StorageCutover(
    directory: Directory('${support.path}/storage-coordination'),
    legacy: LegacySourceStore(
      source: LegacySource(
        File('${documents.path}/bullbitcoin_sqlite.sqlite'),
        SqliteDatabase.currentSchemaVersion,
      ),
      create: SqliteDatabase.new,
    ),
    expectedOwners: storageOwnerManifest,
    participants: [
      if (task == BackgroundTask.walletsSync)
        ElectrumImport(file: File('${support.path}/databases/electrum.sqlite')),
      if (task == BackgroundTask.arkRenewal ||
          task == BackgroundTask.walletsSync)
        PreferencesImport(
          file: preferencesFile,
          defaultRecoverBullServerUrl: recoverBullDefaultServerUrl,
        ),
    ],
  );
  final admitted = await cutover.admit();
  if (admitted case Err()) {
    return BackgroundTaskRunner(
      logger: logger,
      handlers: {task: () async => const BackgroundTaskExecutionResult.retry()},
    );
  }
  final admission = (admitted as Ok<RuntimeAdmission, Failure>).value;
  return BackgroundTaskRunner.forTask(
    admission: admission,
    task: task,
    logger: logger,
    intervals: intervals,
    tasks: {
      BackgroundTask.arkRenewal: (resources) => setupArkBackgroundTask(
        resources,
        documents,
        preferencesFile: preferencesFile,
      ),
      BackgroundTask.logsPrune: (resources) async => () async {
        await log.prune();
        return const BackgroundTaskExecutionResult.success();
      },
      BackgroundTask.walletsSync: (resources) async {
        return setupBackgroundWalletTask(
          resources,
          documents,
          clock,
          intervals: intervals,
          preferencesFile: preferencesFile,
        );
      },
    },
  );
}
