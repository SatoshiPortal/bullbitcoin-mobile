import 'package:drift/drift.dart';
import 'package:labels/frozen_utxos_table.dart';
import 'package:labels/frozen_utxos_table.drift.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

import 'frozen_utxos_freeze_store.drift.dart';

/// User freezes in the encrypted Labels store. Sync reads and changes them
/// through this port from the foreground; its queue orders every live change.
///
/// A database that cannot be opened, read or written is an [Err], never an
/// empty list. A fresh install opens the table initialized by owner cutover.
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
