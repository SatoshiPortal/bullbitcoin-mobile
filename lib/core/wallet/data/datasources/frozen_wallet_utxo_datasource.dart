import 'dart:async';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/models/frozen_wallet_outpoint_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:drift/drift.dart';

/// Persistence for user-frozen wallet outputs, backed by the `frozen_utxos`
/// drift table.
///
/// Drift serializes writes and offers `batch()`, so no app-level lock is
/// needed. The API speaks outpoints — the table stores `walletId/txId/vout`,
/// the same vocabulary `buildPsbt`/payjoin use. `walletId` IS the wallet
/// origin; it attributes a freeze for BIP329 export, never for exclusion.
class FrozenWalletUtxoDatasource {
  final SqliteDatabase _db;
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  FrozenWalletUtxoDatasource({required this._db});

  Stream<void> get changes => _changes.stream;

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
    _changes.add(null);
  }

  Future<void> restoreFrozenWalletOutpoints(
    List<FrozenWalletOutpointModel> outpoints,
  ) async {
    if (outpoints.isEmpty) return;
    await _db.batch((batch) {
      for (final outpoint in outpoints) {
        batch.insert(
          _db.frozenUtxos,
          FrozenUtxosCompanion.insert(
            walletId: outpoint.walletId,
            txId: outpoint.txId,
            vout: outpoint.vout,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
    _changes.add(null);
  }

  /// Deletes the freeze rows for the given outpoints.
  ///
  /// Matched by outpoint only — symmetric with exclusion ([getAllFrozen]),
  /// which is also by outpoint. [walletId] is intentionally NOT in the
  /// predicate: a coin shown as frozen must always be unfreezable, even when
  /// its row carries a different `walletId` than the unfreezing wallet's origin
  /// (e.g. a BIP329 import stored unattributed as `walletId = ''`, or under a
  /// sibling origin). An outpoint is globally unique, so this removes only that
  /// coin's freeze.
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
              row.txId.equals(outpoint.txId) & row.vout.equals(outpoint.vout),
        );
      }
    });
    _changes.add(null);
  }

  /// Returns the frozen outpoints attributed to a wallet.
  Future<List<Outpoint>> getFrozenOutpoints({required String walletId}) async {
    final rows = await (_db.select(
      _db.frozenUtxos,
    )..where((row) => row.walletId.equals(walletId))).get();
    return rows.map((row) => (txId: row.txId, vout: row.vout)).toList();
  }

  /// Returns every frozen row across all wallets, each tagged with the
  /// `walletId` that froze it. `walletId` IS the wallet origin (`wallet.id =>
  /// origin`, e.g. `wpkh([0f36572d/84h/1h/0h])`), so this is the global,
  /// wallet-attributed freeze set the BIP329 export projects to `spendable`.
  Future<List<FrozenWalletOutpointModel>> getAllFrozen() async {
    final rows = await _db.select(_db.frozenUtxos).get();
    return rows
        .map(
          (row) => FrozenWalletOutpointModel(
            walletId: row.walletId,
            txId: row.txId,
            vout: row.vout,
          ),
        )
        .toList(growable: false);
  }
}
