import 'package:bb_mobile/core/recoverbull/domain/entity/key_server_telemetry.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';

/// Persistence for the brute-force telemetry baseline: the `/attempts`
/// polling state per key-server URL, and the user's own operation counters
/// per monitored backup.
///
/// All state is scoped per key-server URL: changing the URL invalidates
/// ETag, baselines and `collectionStartedAt` — identifiers and snapshots
/// from different servers are unrelated.
///
/// Drift row types never leave this datasource: the domain mirrors
/// ([TelemetryServerState], [TelemetryBackupState]) cross the boundary, so
/// the core layer stays independent of the storage schema.
class RecoverbullTelemetryDatasource {
  final SqliteDatabase _sqlite;

  RecoverbullTelemetryDatasource({required this._sqlite});

  // --- Server polling state (one row per key-server URL) ---

  Future<TelemetryServerState?> fetchServerState(String serverUrl) async {
    final row = await _sqlite.managers.recoverbullTelemetryServer
        .filter((f) => f.serverUrl(serverUrl))
        .getSingleOrNull();
    return row == null ? null : _toServerState(row);
  }

  Future<void> upsertServerState(TelemetryServerState state) {
    return _sqlite
        .into(_sqlite.recoverbullTelemetryServer)
        .insertOnConflictUpdate(_toServerRow(state));
  }

  // --- Per-backup baselines ---

  Future<List<TelemetryBackupState>> fetchBackups(String serverUrl) async {
    final rows = await _sqlite.managers.recoverbullTelemetryBackup
        .filter((f) => f.serverUrl(serverUrl))
        .get();
    return rows.map(_toBackupState).toList();
  }

  Future<TelemetryBackupState?> fetchBackup(
    String serverUrl,
    String backupIdHash,
  ) async {
    final row = await _sqlite.managers.recoverbullTelemetryBackup
        .filter((f) => f.serverUrl(serverUrl) & f.backupIdHash(backupIdHash))
        .getSingleOrNull();
    return row == null ? null : _toBackupState(row);
  }

  Future<void> upsertBackup(TelemetryBackupState state) {
    return _sqlite
        .into(_sqlite.recoverbullTelemetryBackup)
        .insertOnConflictUpdate(_toBackupRow(state));
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

  // --- Mapping (epoch seconds on disk, DateTime in the domain) ---

  static DateTime? _fromEpoch(int? seconds) => seconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

  static int? _toEpoch(DateTime? value) =>
      value == null ? null : value.toUtc().millisecondsSinceEpoch ~/ 1000;

  static TelemetryServerState _toServerState(RecoverbullTelemetryServerRow r) =>
      TelemetryServerState(
        serverUrl: r.serverUrl,
        lastEtag: r.lastEtag,
        lastSuccessfulCheckAt: _fromEpoch(r.lastSuccessfulCheckAt),
        collectionStartedAt: _fromEpoch(r.collectionStartedAt),
        consecutiveFailures: r.consecutiveFailures,
        unavailabilityWarnedAt: _fromEpoch(r.unavailabilityWarnedAt),
      );

  static RecoverbullTelemetryServerRow _toServerRow(TelemetryServerState s) =>
      RecoverbullTelemetryServerRow(
        serverUrl: s.serverUrl,
        lastEtag: s.lastEtag,
        lastSuccessfulCheckAt: _toEpoch(s.lastSuccessfulCheckAt),
        collectionStartedAt: _toEpoch(s.collectionStartedAt),
        consecutiveFailures: s.consecutiveFailures,
        unavailabilityWarnedAt: _toEpoch(s.unavailabilityWarnedAt),
      );

  static TelemetryBackupState _toBackupState(RecoverbullTelemetryBackupRow r) =>
      TelemetryBackupState(
        serverUrl: r.serverUrl,
        backupIdHash: r.backupIdHash,
        expectedTotalAttempts: r.expectedTotalAttempts,
        currentWindow: r.currentWindowStartedAt,
        lastWarningWindow: r.lastWarningWindowStartedAt,
        acknowledgedAt: _fromEpoch(r.acknowledgedAt),
      );

  static RecoverbullTelemetryBackupRow _toBackupRow(TelemetryBackupState s) =>
      RecoverbullTelemetryBackupRow(
        serverUrl: s.serverUrl,
        backupIdHash: s.backupIdHash,
        expectedTotalAttempts: s.expectedTotalAttempts,
        currentWindowStartedAt: s.currentWindow,
        lastWarningWindowStartedAt: s.lastWarningWindow,
        acknowledgedAt: _toEpoch(s.acknowledgedAt),
      );
}
