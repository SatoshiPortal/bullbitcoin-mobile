import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:drift/drift.dart';

/// Persistence for user-frozen wallet outputs, backed by the `frozen_utxos`
/// drift table.
///
/// Drift serializes writes and offers `batch()`, so no app-level lock is
/// needed. The API speaks outpoints — the table only stores
/// `walletId/txId/vout/origin`, the same vocabulary `buildPsbt`/payjoin use.
class FrozenWalletUtxoDatasource {
  final SqliteDatabase _db;

  FrozenWalletUtxoDatasource({required SqliteDatabase db}) : _db = db; // ignore: prefer_initializing_formals
  // Named `db` (not `_db`) so callers read `db:`; the field stays private.

  /// Upserts a freeze row per outpoint. All-or-nothing via a single batch.
  Future<void> freezeOutpoints({
    required String walletId,
    required List<Outpoint> outpoints,
    String origin = 'user',
  }) async {
    if (outpoints.isEmpty) return;
    await _db.batch((batch) {
      for (final outpoint in outpoints) {
        batch.insert(
          _db.frozenUtxos,
          FrozenUtxosCompanion.insert(
            walletId: walletId,
            txId: outpoint.txId,
            vout: outpoint.vout,
            origin: Value(origin),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Deletes freeze rows for the given outpoints. Only ever touches
  /// `origin = 'user'` rows — a user can never unfreeze a system/payjoin lock.
  Future<void> unfreezeOutpoints({
    required String walletId,
    required List<Outpoint> outpoints,
  }) async {
    if (outpoints.isEmpty) return;
    await _db.batch((batch) {
      for (final outpoint in outpoints) {
        batch.deleteWhere(
          _db.frozenUtxos,
          (row) =>
              row.walletId.equals(walletId) &
              row.txId.equals(outpoint.txId) &
              row.vout.equals(outpoint.vout) &
              row.origin.equals('user'),
        );
      }
    });
  }

  /// Returns the frozen outpoints for a wallet. `origins == null` returns all
  /// rows (the send-exclusion read); pass `{'user'}` for the user-frozen set
  /// the Coins UI shows/toggles.
  Future<List<Outpoint>> getFrozenOutpoints({
    required String walletId,
    Set<String>? origins,
  }) async {
    final query = _db.select(_db.frozenUtxos)
      ..where((row) => row.walletId.equals(walletId));
    if (origins != null) {
      query.where((row) => row.origin.isIn(origins));
    }
    final rows = await query.get();
    return rows.map((row) => (txId: row.txId, vout: row.vout)).toList();
  }
}
