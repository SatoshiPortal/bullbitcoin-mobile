import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

/// The published `frozen_utxos` table (schema v15), read once by sync to
/// import it. Nothing writes that table any more; it stays intact.
class LegacyFrozenUtxosSource implements LegacyFreezeSourcePort {
  final SqliteDatabase _sqlite;

  LegacyFrozenUtxosSource({required this._sqlite});

  @override
  Future<Result<List<FrozenOutpoint>, SyncFailure>> readAll() async {
    try {
      // Opening the database runs its migrations first: the table read is
      // the published one, created empty on a fresh install.
      final rows = await _sqlite.transaction(
        () => _sqlite.select(_sqlite.frozenUtxos).get(),
      );
      return Ok([
        for (final row in rows)
          FrozenOutpoint((
            txId: row.txId,
            vout: row.vout,
          ), origin: row.walletId),
      ]);
    } on Exception {
      return const Err(SyncStorageFailure());
    }
  }
}
