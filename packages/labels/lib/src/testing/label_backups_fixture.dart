import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:drift/native.dart';
import 'package:labels/frozen_utxos_table.drift.dart';
import 'package:labels/labels_table.dart' show LabelTypeColumn;
import 'package:labels/labels_table.drift.dart';

import '../data/labels_database.dart';
import '../domain/wallet_freeze_port.dart';
import '../public/labels.dart' show LabelBackups, createLabelBackupsForTesting;

/// The real label backup engine over an in-memory database, for tests of the
/// members that drive it. Wallet ownership of coins is declared with [own].
final class LabelBackupsFixture {
  final LabelBackups backups;
  final LabelsDatabase _database;
  final _Freezes _freezes;

  LabelBackupsFixture._(this.backups, this._database, this._freezes);

  factory LabelBackupsFixture.open() {
    final database = LabelsDatabase(NativeDatabase.memory());
    final freezes = _Freezes(database);
    return LabelBackupsFixture._(
      createLabelBackupsForTesting(database: database, walletFreeze: freezes),
      database,
      freezes,
    );
  }

  /// Declares that [walletId] holds the coin, so a freeze of it is accepted.
  /// Runs after each coin is frozen, for a test that acts between two freezes.
  void Function()? get onFreeze => _freezes.onFreeze;
  set onFreeze(void Function()? hook) => _freezes.onFreeze = hook;

  void own(String walletId, String txId, int vout) =>
      (_freezes.owned[walletId] ??= {}).add((txId: txId, vout: vout));

  /// Stores a transaction label attributed to [walletId].
  Future<void> addTransactionLabel({
    required String walletId,
    required String txId,
    required String label,
  }) => _database
      .into(_database.labelsTable)
      .insert(
        LabelsTableCompanion.insert(
          label: label,
          reference: txId,
          type: LabelTypeColumn.tx,
          origin: Value(walletId),
        ),
      );

  /// Freezes a coin of [walletId] as the wallet would have.
  Future<void> freeze(String walletId, String txId, int vout) =>
      _freezes.freeze([(walletId: walletId, txId: txId, vout: vout)]);

  Future<List<({String walletId, String txId, int vout})>> frozen() =>
      _freezes.getAllFrozen();

  Future<List<({String label, String reference, String? origin})>>
  labels() async => [
    for (final row in await _database.select(_database.labelsTable).get())
      (label: row.label, reference: row.reference, origin: row.origin),
  ];

  Future<void> close() => _database.close();
}

final class _Freezes implements WalletFreezePort {
  final LabelsDatabase _db;
  final owned = <String, Set<({String txId, int vout})>>{};
  void Function()? onFreeze;

  _Freezes(this._db);

  @override
  Future<void> freeze(
    List<({String? walletId, String txId, int vout})> outputs,
  ) async {
    for (final output in outputs) {
      await _db
          .into(_db.frozenUtxos)
          .insert(
            FrozenUtxosCompanion.insert(
              walletId: output.walletId ?? '',
              txId: output.txId,
              vout: output.vout,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      onFreeze?.call();
    }
  }

  @override
  Future<List<({String walletId, String txId, int vout})>>
  getAllFrozen() async => [
    for (final row in await _db.select(_db.frozenUtxos).get())
      (walletId: row.walletId, txId: row.txId, vout: row.vout),
  ];

  @override
  Future<List<({String txId, int vout})>> getOwnedOutpoints({
    required String walletId,
  }) async => owned[walletId]?.toList() ?? [];
}
