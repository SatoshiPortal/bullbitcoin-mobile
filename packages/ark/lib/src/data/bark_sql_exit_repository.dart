import 'dart:io';
import 'dart:typed_data';

import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/ark_sql_exit_repository.dart';
import '../domain/ark_wallet_failure.dart';
import '../domain/entities/ark_sql_exit.dart';
import 'bark_sql_exit_codec.dart';
import 'bark_sql_schema.dart';

/// Short per-call readonly snapshots; no native wallet, file creation or service.
final class BarkSqlExitRepository implements ArkSqlExitRepository {
  final String databasePath;
  final BarkSqlSchema schema;
  static const _maxBytes = 1024 * 1024;
  BarkSqlExitRepository({required this.databasePath, required this.schema});

  Future<Result<ArkSqlRead<T>, ArkWalletFailure>> _read<T>(
    bool validId,
    T? Function(Database) query,
  ) async {
    if (!validId) return const Err(ArkValidationFailure());
    try {
      if (!File(databasePath).existsSync()) {
        return const Err(
          ArkUnavailableFailure(ArkFailureReason.accountMissing),
        );
      }
      final db = sqlite3.open(databasePath, mode: OpenMode.readOnly);
      var transaction = false;
      Error? primary;
      try {
        db.execute('PRAGMA busy_timeout=0');
        db.execute('PRAGMA query_only=ON');
        if (db.select('PRAGMA query_only').single.values.single != 1) {
          throw const FormatException();
        }
        db.execute('BEGIN');
        transaction = true;
        final checked = schema.validate(db);
        if (checked case Err(:final failure)) return Err(failure);
        final value = query(db);
        return Ok(value == null ? ArkSqlNotFound<T>() : ArkSqlFound(value));
      } on Error catch (error) {
        primary = error;
        rethrow;
      } finally {
        try {
          if (transaction) db.execute('ROLLBACK');
        } catch (error) {
          if (primary == null) {
            if (error is Error) primary = error;
            rethrow;
          }
        } finally {
          try {
            db.close();
          } catch (_) {
            if (primary == null) rethrow;
          }
        }
      }
    } on FormatException {
      return const Err(ArkStorageFailure(ArkFailureReason.storeIncompatible));
    } on SqliteException {
      return const Err(ArkStorageFailure());
    } on FileSystemException {
      return const Err(ArkStorageFailure());
    }
  }

  Row? _row(ResultSet rows, String id, String key) {
    if (rows.isEmpty) return null;
    if (rows.length != 1 || rows.single[key] != id) {
      throw const FormatException();
    }
    return rows.single;
  }

  void _size(
    Row row,
    String prefix,
    String kind, {
    bool nullable = false,
    bool nonempty = false,
  }) {
    final actual = row['${prefix}_kind'], length = row['${prefix}_bytes'];
    if (nullable && actual == 'null' && length == null) return;
    if (actual != kind ||
        length is! int ||
        length < (nonempty ? 1 : 0) ||
        length > _maxBytes) {
      throw const FormatException();
    }
  }

  Row _payload(Database db, String sql, String id, String key) {
    final row = _row(db.select(sql, [id]), id, key);
    if (row == null) throw const FormatException();
    return row;
  }

  String _text(Object? value) {
    if (value is! String) throw const FormatException();
    return value;
  }

  List<int>? _component(Object? value) {
    if (value == null) return null;
    if (value is Uint8List) return value;
    throw const FormatException();
  }

  @override
  Future<Result<ArkSqlRead<ArkSqlExitState>, ArkWalletFailure>> readExitState({
    required String vtxoId,
  }) => _read(isSqlVtxoId(vtxoId), (db) {
    final metadata = _row(
      db.select(
        'SELECT vtxo_id,typeof(state) AS state_kind,length(CAST(state AS BLOB)) AS state_bytes FROM bark_exit_states WHERE vtxo_id=?',
        [vtxoId],
      ),
      vtxoId,
      'vtxo_id',
    );
    if (metadata == null) return null;
    _size(metadata, 'state', 'text');
    final row = _payload(
      db,
      'SELECT vtxo_id,state FROM bark_exit_states WHERE vtxo_id=?',
      vtxoId,
      'vtxo_id',
    );
    return decodeSqlExitState(vtxoId, _text(row['state']));
  });

  @override
  Future<Result<ArkSqlRead<ArkSqlExitChild>, ArkWalletFailure>> readExitChild({
    required String parentTxid,
  }) => _read(isSqlTxid(parentTxid), (db) {
    final metadata = _row(
      db.select(
        'SELECT exit_id,typeof(child_tx) AS child_kind,length(child_tx) AS child_bytes,typeof(tx_origin) AS origin_kind,length(CAST(tx_origin AS BLOB)) AS origin_bytes FROM bark_exit_child_transactions WHERE exit_id=?',
        [parentTxid],
      ),
      parentTxid,
      'exit_id',
    );
    if (metadata == null) return null;
    _size(metadata, 'child', 'blob', nonempty: true);
    _size(metadata, 'origin', 'text');
    final row = _payload(
      db,
      'SELECT exit_id,child_tx,tx_origin FROM bark_exit_child_transactions WHERE exit_id=?',
      parentTxid,
      'exit_id',
    );
    final bytes = row['child_tx'];
    if (bytes is! Uint8List) throw const FormatException();
    final origin = decodeSqlExitOrigin(_text(row['tx_origin']));
    return ArkSqlExitChild(
      parentTxid: parentTxid,
      transactionBytes: bytes,
      origin: origin.$1,
      confirmedIn: origin.$2,
    );
  });

  @override
  Future<Result<ArkSqlRead<ArkSqlVtxoComponents>, ArkWalletFailure>> readVtxo({
    required String vtxoId,
  }) => _read(isSqlVtxoId(vtxoId), (db) {
    final metadata = _row(
      db.select(
        'SELECT id,typeof(raw_bare) AS bare_kind,length(raw_bare) AS bare_bytes,typeof(raw_genesis) AS genesis_kind,length(raw_genesis) AS genesis_bytes FROM bark_vtxo WHERE id=?',
        [vtxoId],
      ),
      vtxoId,
      'id',
    );
    if (metadata == null) return null;
    _size(metadata, 'bare', 'blob', nullable: true);
    _size(metadata, 'genesis', 'blob', nullable: true);
    final row = _payload(
      db,
      'SELECT id,raw_bare,raw_genesis FROM bark_vtxo WHERE id=?',
      vtxoId,
      'id',
    );
    return ArkSqlVtxoComponents(
      vtxoId: vtxoId,
      rawBare: _component(row['raw_bare']),
      rawGenesis: _component(row['raw_genesis']),
    );
  });
}
