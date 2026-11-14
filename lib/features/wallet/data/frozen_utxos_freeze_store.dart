import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

/// User freezes, kept in the published `frozen_utxos` table (schema v15).
/// Sync reads and changes them through this store from the foreground; no
/// other code writes the table.
///
/// A database that cannot be opened, read or written is an [Err], never an
/// empty list. Opening it runs its migrations first, so a fresh install reads
/// the table created empty.
class FrozenUtxosFreezeStore implements FreezeStorePort {
  final SqliteDatabase _sqlite;

  FrozenUtxosFreezeStore({required this._sqlite});

  @override
  Future<Result<List<FrozenOutpoint>, SyncFailure>> readAll() async {
    try {
      return Ok(await _sqlite.transaction(_rows));
    } on Exception {
      return const Err(SyncStorageFailure());
    }
  }

  @override
  Future<Result<void, SyncFailure>> freeze(List<FrozenOutpoint> rows) async {
    try {
      await _sqlite.batch(
        (batch) => batch.insertAll(_sqlite.frozenUtxos, [
          for (final row in rows)
            FrozenUtxosCompanion.insert(
              walletId: row.origin,
              txId: row.outpoint.txId,
              vout: row.outpoint.vout,
            ),
        ], mode: InsertMode.insertOrIgnore),
      );
      return const Ok(null);
    } on Exception {
      return const Err(SyncStorageFailure());
    }
  }

  @override
  Future<Result<void, SyncFailure>> unfreeze(List<Outpoint> outpoints) async {
    try {
      await _sqlite.batch((batch) {
        for (final outpoint in outpoints) {
          // Every origin: a coin shown frozen is always unfreezable.
          batch.deleteWhere(
            _sqlite.frozenUtxos,
            (row) =>
                row.txId.equals(outpoint.txId) & row.vout.equals(outpoint.vout),
          );
        }
      });
      return const Ok(null);
    } on Exception {
      return const Err(SyncStorageFailure());
    }
  }

  /// Drift runs this database's statements made outside the transaction
  /// only once it ends, so no freeze of this app commits meanwhile. ⚠️ The
  /// whole app database waits too: [body] stays short, and never awaits a
  /// statement issued outside its own zone, which would wait for it forever.
  @override
  Future<Result<T, SyncFailure>> guard<T>(
    Future<T> Function(List<FrozenOutpoint> rows) body,
  ) async {
    // Set only when [body] throws, so its exception is rethrown as it is
    // rather than taken for a storage failure.
    (Object, StackTrace)? thrown;
    try {
      return Ok(
        await _sqlite.transaction(() async {
          final rows = await _rows();
          try {
            return await body(rows);
          } on Object catch (error, trace) {
            thrown = (error, trace);
            rethrow;
          }
        }),
      );
    } on Exception {
      if (thrown case (final error, final trace)) {
        Error.throwWithStackTrace(error, trace);
      }
      return const Err(SyncStorageFailure());
    }
  }

  Future<List<FrozenOutpoint>> _rows() async => [
    for (final row in await _sqlite.select(_sqlite.frozenUtxos).get())
      FrozenOutpoint((txId: row.txId, vout: row.vout), origin: row.walletId),
  ];
}
