import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';

/// Persistence for the brute-force telemetry baseline: the `/attempts`
/// polling state per key-server URL, and the user's own operation counters
/// per monitored backup.
///
/// All state is scoped per key-server URL: changing the URL invalidates
/// ETag, baselines and `collectionStartedAt` — identifiers and snapshots
/// from different servers are unrelated.
class RecoverbullTelemetryDatasource {
  final SqliteDatabase _sqlite;

  RecoverbullTelemetryDatasource({required this._sqlite});

  // --- Server polling state (one row per key-server URL) ---

  Future<RecoverbullTelemetryServerRow?> fetchServerState(String serverUrl) {
    return _sqlite.managers.recoverbullTelemetryServer
        .filter((f) => f.serverUrl(serverUrl))
        .getSingleOrNull();
  }

  Future<void> upsertServerState(RecoverbullTelemetryServerRow row) {
    return _sqlite
        .into(_sqlite.recoverbullTelemetryServer)
        .insertOnConflictUpdate(row);
  }

  // --- Per-backup baselines ---

  Future<List<RecoverbullTelemetryBackupRow>> fetchBackups(String serverUrl) {
    return _sqlite.managers.recoverbullTelemetryBackup
        .filter((f) => f.serverUrl(serverUrl))
        .get();
  }

  Future<RecoverbullTelemetryBackupRow?> fetchBackup(
    String serverUrl,
    String backupIdHash,
  ) {
    return _sqlite.managers.recoverbullTelemetryBackup
        .filter((f) => f.serverUrl(serverUrl) & f.backupIdHash(backupIdHash))
        .getSingleOrNull();
  }

  Future<void> upsertBackup(RecoverbullTelemetryBackupRow row) {
    return _sqlite
        .into(_sqlite.recoverbullTelemetryBackup)
        .insertOnConflictUpdate(row);
  }

  /// The key-server URL changed: identifiers and snapshots from different
  /// servers are unrelated, so every row of the old server is dropped.
  Future<void> deleteAllForServer(String serverUrl) async {
    await _sqlite.managers.recoverbullTelemetryServer
        .filter((f) => f.serverUrl(serverUrl))
        .delete();
    await _sqlite.managers.recoverbullTelemetryBackup
        .filter((f) => f.serverUrl(serverUrl))
        .delete();
  }

  /// App data reset: wipe every telemetry row.
  Future<void> clearAll() async {
    await _sqlite.managers.recoverbullTelemetryServer.delete();
    await _sqlite.managers.recoverbullTelemetryBackup.delete();
  }
}
