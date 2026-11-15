import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

/// What a prefill handed the client, for the sync log.
typedef ElectrumCachePrefill = ({
  int transactions,
  int parents,
  int anchors,
  int droppedParents,
  bool failed,
});

/// Parents downloaded and stored after a scan, for the sync log.
typedef ElectrumCacheParents = ({int stored, bool failed});

/// The sidecar database of parent transactions, beside a BDK wallet store.
/// Only public chain data is stored; the bytes are verified by the reader.
/// A cache failure only costs the downloads.
final class ElectrumCacheDatasource {
  final Database _db;

  /// Whether [open] had to delete an unreadable sidecar.
  final bool rebuilt;

  ElectrumCacheDatasource._(this._db, {required this.rebuilt});

  static String pathFor(String walletDatabasePath) =>
      '$walletDatabasePath.parents.sqlite';

  /// Opens the sidecar of [walletDatabasePath], rebuilding it when it is
  /// unreadable. Returns null when it cannot be used at all.
  static ElectrumCacheDatasource? open(String walletDatabasePath) {
    final path = pathFor(walletDatabasePath);
    for (var attempt = 0; attempt < 2; attempt++) {
      Database? db;
      try {
        db = sqlite3.open(path);
        db.execute('PRAGMA busy_timeout = 5000');
        db.execute(
          'CREATE TABLE IF NOT EXISTS parent_transaction '
          '(txid TEXT PRIMARY KEY NOT NULL, raw BLOB NOT NULL) WITHOUT ROWID',
        );
        return ElectrumCacheDatasource._(db, rebuilt: attempt > 0);
      } catch (_) {
        db?.dispose();
        _deleteFiles(path);
      }
    }
    return null;
  }

  /// The cache part of a sync log line: counts only, no identifiers.
  static String describe({
    required bool opened,
    required bool rebuilt,
    ElectrumCachePrefill? prefill,
    ElectrumCacheParents? parents,
  }) {
    final state = !opened
        ? 'unavailable'
        : prefill == null || prefill.failed || (parents?.failed ?? false)
        ? 'degraded'
        : rebuilt
        ? 'rebuilt'
        : 'ok';
    return 'cache=$state '
        'prefilled_txs=${prefill?.transactions ?? 0} '
        'prefilled_parents=${prefill?.parents ?? 0} '
        'anchors=${prefill?.anchors ?? 0} '
        'dropped_parents=${prefill?.droppedParents ?? 0} '
        'stored_parents=${parents?.stored ?? 0}';
  }

  /// Removes the sidecar along with its wallet.
  static void delete(String walletDatabasePath) =>
      _deleteFiles(pathFor(walletDatabasePath));

  /// Every stored parent, as written; the caller verifies the bytes.
  List<(String, Uint8List)> storedParents() => [
    for (final row in _db.select('SELECT txid, raw FROM parent_transaction'))
      (row['txid'] as String, row['raw'] as Uint8List),
  ];

  Set<String> knownParents() => {
    for (final row in _db.select('SELECT txid FROM parent_transaction'))
      row['txid'] as String,
  };

  void dropParents(Iterable<String> txids) {
    for (final txid in txids) {
      _db.execute('DELETE FROM parent_transaction WHERE txid = ?', [txid]);
    }
  }

  /// Stores [parents] in one transaction: all of them or none.
  void storeParents(Map<String, Uint8List> parents) {
    final insert = _db.prepare(
      'INSERT OR IGNORE INTO parent_transaction (txid, raw) VALUES (?, ?)',
    );
    try {
      _db.execute('BEGIN IMMEDIATE');
      try {
        for (final MapEntry(key: txid, value: raw) in parents.entries) {
          insert.execute([txid, raw]);
        }
        _db.execute('COMMIT');
      } catch (_) {
        _db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      insert.dispose();
    }
  }

  void close() => _db.dispose();

  static void _deleteFiles(String path) {
    for (final suffix in const ['', '-journal', '-wal', '-shm']) {
      try {
        final file = File('$path$suffix');
        if (file.existsSync()) file.deleteSync();
      } catch (_) {
        // Left for the next open or delete to retry.
      }
    }
  }
}
