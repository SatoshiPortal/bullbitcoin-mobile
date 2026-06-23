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

  /// Upserts a freeze row per outpoint, attributed to [walletId] (the wallet
  /// origin). All-or-nothing via a single batch.
  Future<void> freezeOutpoints({
    required String walletId,
    required List<Outpoint> outpoints,
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
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Deletes the freeze rows for the given outpoints under [walletId].
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
              row.vout.equals(outpoint.vout),
        );
      }
    });
  }

  /// Returns the frozen outpoints attributed to a wallet.
  Future<List<Outpoint>> getFrozenOutpoints({
    required String walletId,
  }) async {
    final rows = await (_db.select(_db.frozenUtxos)
          ..where((row) => row.walletId.equals(walletId)))
        .get();
    return rows.map((row) => (txId: row.txId, vout: row.vout)).toList();
  }

  /// Returns every frozen row across all wallets, each tagged with the
  /// `walletId` that froze it. `walletId` IS the wallet origin (`wallet.id =>
  /// origin`, e.g. `wpkh([0f36572d/84h/1h/0h])`), so this is the global,
  /// wallet-attributed freeze set the BIP329 export projects to `spendable`.
  Future<List<({String walletId, String txId, int vout})>>
  getAllFrozen() async {
    final rows = await _db.select(_db.frozenUtxos).get();
    return rows
        .map(
          (row) => (walletId: row.walletId, txId: row.txId, vout: row.vout),
        )
        .toList();
  }
}
