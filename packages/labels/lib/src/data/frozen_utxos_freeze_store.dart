import 'package:drift/drift.dart';
import 'package:labels/frozen_utxos_table.dart';
import 'package:labels/frozen_utxos_table.drift.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

import 'frozen_utxos_freeze_store.drift.dart';

/// User freezes, kept in the published `frozen_utxos` table (schema v15).
/// Sync reads and changes them through this store from the foreground; no
/// other code writes the table, so sync's own queue orders every change.
///
/// A database that cannot be opened, read or written is an [Err], never an
/// empty list. Opening it runs its migrations first, so a fresh install reads
/// the table created empty.
@DriftAccessor(tables: [FrozenUtxos])
class FrozenUtxosFreezeStore extends DatabaseAccessor<GeneratedDatabase>
    with $FrozenUtxosFreezeStoreMixin
    implements FreezeStorePort {
  FrozenUtxosFreezeStore({required GeneratedDatabase database})
    : super(database);

  @override
  Future<Result<List<FrozenOutpoint>, SyncFailure>> readAll() async {
    try {
      return Ok(await transaction(_rows));
    } on Exception {
      return const Err(SyncStorageFailure());
    }
  }

  @override
  Future<Result<void, SyncFailure>> freeze(List<FrozenOutpoint> rows) async {
    try {
      await batch(
        (changes) => changes.insertAll(frozenUtxos, [
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
      await batch((changes) {
        for (final outpoint in outpoints) {
          // Every origin: a coin shown frozen is always unfreezable.
          changes.deleteWhere(
            frozenUtxos,
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
    for (final row in await select(frozenUtxos).get())
      FrozenOutpoint((txId: row.txId, vout: row.vout), origin: row.walletId),
  ];
}
