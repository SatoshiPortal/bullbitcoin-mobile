import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';

/// Records when the app broadcast an outgoing transaction.
///
/// Wallet transactions are never persisted — BDK and LWK rebuild them on every
/// sync — and their only recoverable timestamp is the confirming block, which
/// for a send lands minutes to hours after the user actually sent. The moment
/// is captured here or it is lost.
class SendTimestampDatasource {
  final SqliteDatabase _db;

  SendTimestampDatasource({required this._db});

  /// Records [txid] as broadcast at [sentAt].
  ///
  /// Uses insert-or-ignore: a rebroadcast of the same transaction must not
  /// move its original send moment forward.
  Future<void> record({required String txid, required DateTime sentAt}) async {
    await _db
        .into(_db.sendTimestamps)
        .insert(
          SendTimestampsCompanion.insert(
            txid: txid,
            sentAtSecs: sentAt.toUtc().millisecondsSinceEpoch ~/ 1000,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<DateTime?> fetch(String txid) async {
    final row = await (_db.select(
      _db.sendTimestamps,
    )..where((t) => t.txid.equals(txid))).getSingleOrNull();
    if (row == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      row.sentAtSecs * 1000,
      isUtc: true,
    );
  }

  /// Every recorded send moment, keyed by txid.
  ///
  /// The transaction list resolves anchors for many rows at once, so it reads
  /// the whole table in one query rather than once per row.
  Future<Map<String, DateTime>> fetchAll() async {
    final rows = await _db.select(_db.sendTimestamps).get();
    return {
      for (final row in rows)
        row.txid: DateTime.fromMillisecondsSinceEpoch(
          row.sentAtSecs * 1000,
          isUtc: true,
        ),
    };
  }
}
