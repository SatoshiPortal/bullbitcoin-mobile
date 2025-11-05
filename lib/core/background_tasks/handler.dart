import 'package:bb_mobile/core/background_tasks/sync.dart';
import 'package:bb_mobile/core/background_tasks/tasks.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/logger.dart' show Logger;
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void backgroundTasksHandler() {
  Workmanager().executeTask((task, inputData) async {
    return await tasksHandler(task);
  });
}

Future<bool> tasksHandler(
  String task, {
  SqliteDatabase? alreadyInitializedSqliteDatabase,
}) async {
  final logDirectory = await getApplicationDocumentsDirectory();
  final log = Logger.init(directory: logDirectory);
  await log.ensureLogsExist();
  final startTime = DateTime.now();

  log.config('Starting background task: $task');

  try {
    final backgroundTask = BackgroundTask.fromName(task);
    final sqlite = alreadyInitializedSqliteDatabase ?? SqliteDatabase();

    final electrumServerDatasource = ElectrumServerStorageDatasource(
      sqlite: sqlite,
    );

    final servers = await electrumServerDatasource.fetchAllServers();
    // If custom servers exist, we should use them only
    final customServers = servers.where((s) => s.isCustom).toList();
    final serversToUse = customServers.isNotEmpty ? customServers : servers;
    // Sort servers by priority (lower number means higher priority)
    serversToUse.sort((a, b) => a.priority.compareTo(b.priority));

    final settingsDatasource = SettingsDatasource(sqlite: sqlite);
    final settings = await settingsDatasource.fetch();
    final environment = settings.environment;

    switch (backgroundTask) {
      case BackgroundTask.bitcoinSync:
        await Sync.bitcoin(sqlite, log, serversToUse, environment);
      case BackgroundTask.liquidSync:
        await Sync.liquid(sqlite, log, serversToUse, environment);
    }

    final elapsedTime = DateTime.now().difference(startTime).inSeconds;
    log.fine('Background task $task completed in $elapsedTime seconds');
    return Future.value(true);
  } catch (e) {
    log.shout('Background task $task failed: $e'); // TODO: replace by severe
    return Future.value(false);
  }
}
