import 'package:drift/drift.dart';

import '../../database/recoverbull_database.dart';
import '../../domain/recoverbull_server_url.dart';

class RecoverbullSettingsDatasource {
  final RecoverBullDatabase _database;
  final Uri _defaultServer;

  RecoverbullSettingsDatasource({required this._database, Uri? defaultServer})
    : _defaultServer = defaultServer ?? Uri.parse(recoverBullDefaultServerUrl);

  /// Switches the effective key server. Every monitored backup keeps its
  /// identifier but forgets the old server's counters and is marked to
  /// rebaseline silently on its first observation on the new server.
  Future<void> store(Uri url) async {
    validateRecoverBullServerUrl(url);
    await _database.transaction(() async {
      final state = await _database
          .select(_database.recoverbullState)
          .getSingle();
      final oldEffective = Uri.parse(
        state.serverUrlOverride ?? _defaultServer.toString(),
      );
      if (oldEffective == url) return;
      await (_database.update(_database.recoverbullMonitoredBackup)).write(
        const RecoverbullMonitoredBackupCompanion(
          expectedServerDistinctCandidateTotal: Value(0),
          currentWindow: Value(0),
          // Zero is a private marker for a row awaiting its first observation
          // on the new server. A newly created row keeps null and still alerts
          // on its first server-side attempt.
          lastWarningWindow: Value(0),
          rowRevision: Value(0),
        ),
      );
      await _database
          .update(_database.recoverbullState)
          .write(
            RecoverbullStateCompanion(
              serverUrlOverride: Value(
                url == _defaultServer ? null : url.toString(),
              ),
              permissionGranted: const Value(false),
              etag: const Value(null),
              collectionStartedAt: const Value(null),
              lastSuccessfulCheckAt: const Value(null),
              consecutiveFailures: const Value(0),
              lastUnavailabilityWarningAt: const Value(null),
              attemptsUnsupportedUntil: const Value(null),
              generation: Value(state.generation + 1),
              revision: Value(state.revision + 1),
            ),
          );
    });
    try {
      await _database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {}
  }

  Future<Uri> fetch() async {
    final row = await _database.select(_database.recoverbullState).getSingle();
    return validateRecoverBullServerUrl(
      Uri.parse(row.serverUrlOverride ?? _defaultServer.toString()),
    );
  }

  Future<void> allowPermission(bool isGranted) async {
    await _database
        .update(_database.recoverbullState)
        .write(RecoverbullStateCompanion(permissionGranted: Value(isGranted)));
  }

  Future<bool> fetchPermission() async {
    final row = await _database.select(_database.recoverbullState).getSingle();
    return row.permissionGranted;
  }

  Future<RecoverbullStateData> fetchState() =>
      _database.select(_database.recoverbullState).getSingle();

  Future<void> markBackupStored() => _database.markEncryptedBackupStored();

  Future<void> markBackupVerified() => _database.markEncryptedBackupVerified();
}
