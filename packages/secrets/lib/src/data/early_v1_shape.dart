import 'package:sqlite3/sqlite3.dart' show SqliteException;

import 'secrets_database.dart';

/// Schema v1 is unpublished, and the files written before `last_view_id`
/// (D102) keep `user_version` 1 without the column.
///
/// Only the foreground app adapts such a file: a WorkManager task that opened
/// it first would migrate alongside the app, which the storage rules forbid.
/// A background opener therefore asks [hasLastViewColumn] and refuses a file
/// that has not been adapted yet.
Future<bool> hasLastViewColumn(SecretsDatabase database) async {
  final table = await database
      .customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' "
        "AND name = 'access_state'",
      )
      .get();
  if (table.isEmpty) return true;
  final column = await database
      .customSelect(
        "SELECT 1 FROM pragma_table_info('access_state') "
        "WHERE name = 'last_view_id'",
      )
      .get();
  return column.isNotEmpty;
}

/// Adds `last_view_id` once, only when missing, under the admission the
/// foreground opener already holds. Nothing is reset. Another foreground
/// connection may add it first: that leaves the guard satisfied, and a busy
/// file is retried a few times before the contention is reported.
Future<void> adaptEarlyV1Shape(SecretsDatabase database) async {
  for (var attempt = 0; ; attempt++) {
    if (await hasLastViewColumn(database)) return;
    try {
      await database.customStatement(
        'ALTER TABLE access_state ADD COLUMN last_view_id TEXT',
      );
      return;
    } on SqliteException catch (error) {
      if (error.message.contains('duplicate column')) return;
      final code = error.extendedResultCode & 0xff;
      final busy = code == 5 || code == 6;
      if (!busy || attempt >= 8) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 25 * (attempt + 1)));
    }
  }
}
