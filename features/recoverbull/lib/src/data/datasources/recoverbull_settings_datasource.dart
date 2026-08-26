import 'package:drift/drift.dart';

import '../../database/recoverbull_database.dart';
import '../../domain/recoverbull_server_url.dart';
import '../../public/recoverbull.dart' show recoverBullDefaultServerUrl;

class RecoverbullSettingsDatasource {
  final RecoverBullDatabase _database;
  final Uri _defaultServer;

  RecoverbullSettingsDatasource({required this._database, Uri? defaultServer})
    : _defaultServer = defaultServer ?? Uri.parse(recoverBullDefaultServerUrl);

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
      await _database.delete(_database.recoverbullMonitoredBackup).go();
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
}
