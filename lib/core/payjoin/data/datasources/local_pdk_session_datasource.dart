import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/pdk_sessions_table.dart';

class LocalPdkSessionDatasource {
  final SqliteDatabase _db;

  LocalPdkSessionDatasource({required SqliteDatabase db}) : _db = db;

  Future<void> store({
    required String token,
    required PdkSessionType type,
    required String session,
  }) async {
    try {
      final row = PdkSessionRow(token: token, type: type, session: session);
      await _db.into(_db.pdkSessions).insertOnConflictUpdate(row);
    } catch (e) {
      throw StorePdkSessionException('$e');
    }
  }

  Future<String?> load(String token) async {
    final row =
        await _db.managers.pdkSessions
            .filter((f) => f.token(token))
            .getSingleOrNull();

    if (row == null) return null;

    return row.session;
  }
}

class StorePdkSessionException implements Exception {
  final String message;

  StorePdkSessionException(this.message);
}
