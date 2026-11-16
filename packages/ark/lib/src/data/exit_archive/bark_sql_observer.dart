import 'dart:convert';
import 'dart:io';

import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../ark.dart';
import 'bark_sql_observation.dart';
import 'bark_sql_schema.dart';

abstract interface class BarkSqlObserverPort {
  String get sourcePath;

  /// Dispose only this owned reader between passes, never mutate the source.
  void reopen();
  Future<Result<BarkSqlObservation, ArkWalletFailure>> read();
  Future<void> close();
}

/// One retained readonly connection, no timer/native opener/account writer.
/// Bounds reject whole observations, never truncate. One SQLite cursor row may
/// materialize before the byte check; this is not a hard process-memory ceiling.
final class SqliteBarkObserver implements BarkSqlObserverPort {
  @override
  final String sourcePath;
  final BarkSqlSchema schema;
  final int maxRows;
  final int maxBytes;
  Database? _db;
  int _epoch = 0;
  bool _closed = false;
  SqliteBarkObserver({
    required this.sourcePath,
    required this.schema,
    this.maxRows = 10000,
    this.maxBytes = 16 * 1024 * 1024,
  }) {
    if (maxRows < 1 || maxBytes < 1) {
      throw ArgumentError('Invalid observation bounds');
    }
  }

  @override
  Future<Result<BarkSqlObservation, ArkWalletFailure>> read() async {
    if (_closed || !schema.permitted) return const Err(ArkUnavailableFailure());
    try {
      if (!File(sourcePath).existsSync()) {
        _db?.close();
        _db = null;
        return const Err(ArkStorageFailure());
      }
      if (_db == null) {
        _db = sqlite3.open(sourcePath, mode: OpenMode.readOnly);
        _db?.execute('PRAGMA busy_timeout=0');
        _db?.execute('PRAGMA query_only=ON');
        _epoch++;
      }
      final db = _db;
      if (db == null) return const Err(ArkStorageFailure());
      if (db.select('PRAGMA query_only').single.values.single != 1) {
        throw const FormatException();
      }
      // Connection-local sample OUTSIDE the snapshot. Later commits are seen
      // next poll; never replace this sample with a later unsignalled value.
      final version = db.select('PRAGMA data_version').single.values.single;
      if (version is! int) throw const FormatException();
      final rows = <BarkSqlOpaqueRow>[];
      final keys = <String>{};
      var used = 0;
      db.execute('BEGIN');
      try {
        for (final entry in BarkSqlSchema.columns.entries) {
          final guarded = schema.validate(db);
          if (guarded case Err(:final failure)) return Err(failure);
          final info = schema.columnInfo(db, entry.key);
          final statement = db.prepare(
            'SELECT ${entry.value.join(',')} FROM ${entry.key} ORDER BY ${entry.value.first}',
          );
          try {
            final cursor = statement.selectCursor();
            while (cursor.moveNext()) {
              if (rows.length >= maxRows) throw const _Deferred();
              final raw = cursor.current;
              var bytes = 0;
              for (final cell in raw.values) {
                bytes += switch (cell) {
                  String text => utf8.encode(text).length,
                  List<int> blob => blob.length,
                  _ => 8,
                };
              }
              if (bytes > maxBytes - used) throw const _Deferred();
              final row = schema.encode(entry.key, raw, info);
              used += utf8.encode(row.payload).length;
              if (used > maxBytes) throw const _Deferred();
              if (!keys.add(jsonEncode([row.sourceTable, row.rowKey]))) {
                throw const FormatException();
              }
              rows.add(row);
            }
          } finally {
            statement.close();
          }
        }
      } finally {
        db.execute('ROLLBACK');
      }
      return Ok(
        BarkSqlObservation(
          schema.account,
          BarkSqlSourceToken(_epoch, version),
          DateTime.now().toUtc(),
          rows,
        ),
      );
    } on _Deferred {
      return const Err(ArkUnavailableFailure());
    } on FormatException {
      return const Err(ArkValidationFailure());
    } on SqliteException {
      _db?.close();
      _db = null;
      return const Err(ArkStorageFailure());
    } on FileSystemException {
      return const Err(ArkStorageFailure());
    }
  }

  @override
  void reopen() {
    _db?.close();
    _db = null;
  }

  @override
  Future<void> close() async {
    _closed = true;
    _db?.close();
    _db = null;
  }
}

final class _Deferred implements Exception {
  const _Deferred();
}
