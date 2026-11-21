import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/frozen_utxos_table.drift.dart';
import 'package:drift/drift.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

/// User freezes, kept in the published `frozen_utxos` table (schema v15).
/// Sync reads and changes them through this store from the foreground; no
/// other code writes the table, so sync's own queue orders every change.
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

  Future<List<FrozenOutpoint>> _rows() async => [
    for (final row in await _sqlite.select(_sqlite.frozenUtxos).get())
      FrozenOutpoint((txId: row.txId, vout: row.vout), origin: row.walletId),
  ];
}
