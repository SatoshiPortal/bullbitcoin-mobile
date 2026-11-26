import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import 'coordination.dart';
import 'legacy_storage.dart';

/// Temporary import support for owners taking one nullable field from a
/// historical wallet row. Owners declare their own physical schema and
/// supply the encrypted opener without giving the coordinator key access.
final class WalletColumnProjection<T extends GeneratedDatabase>
    implements LegacyImportParticipant {
  @override
  final String ownerId;
  final File file;
  final String column;
  final String destinationTable;
  final T Function(QueryExecutor) create;
  final Future<Result<QueryExecutor, LegacyImportFailure>> Function({
    required bool existing,
  })
  openExecutor;

  WalletColumnProjection({
    required this.ownerId,
    required this.file,
    required this.column,
    required this.destinationTable,
    required this.create,
    required this.openExecutor,
  }) {
    final sqlIdentifier = RegExp(r'^[a-z][a-z0-9_]*$');
    if (!sqlIdentifier.hasMatch(column) ||
        !sqlIdentifier.hasMatch(destinationTable)) {
      throw ArgumentError('Invalid projection identifier');
    }
  }

  String get _imported => 'split-v1/$ownerId';
  String get _fresh => 'fresh-v1/$ownerId';

  @override
  Future<bool> hasState() async => [
    '',
    '-wal',
    '-shm',
    '-journal',
    '.retire-pending',
  ].any((suffix) => File('${file.path}$suffix').existsSync());

  @override
  Future<Result<PreparedOwner, LegacyImportFailure>> prepare(
    ExclusiveAdmission admission,
    OwnerOrigin origin,
  ) async => (await _open(
    admission,
    existing: false,
  )).map((store) => _PreparedProjection(this, store));

  @override
  Future<Result<OwnerReadiness, LegacyImportFailure>> inspect(
    LifecycleAdmission admission,
  ) async {
    switch (await _open(admission, existing: true)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        try {
          return await _readiness(value.database);
        } finally {
          await value.close();
        }
    }
  }

  Future<Result<T, LegacyImportFailure>> openRuntime(
    RuntimeAdmission admission,
  ) async {
    switch (await _open(admission, existing: true)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        switch (await _readiness(value.database)) {
          case Ok(value: OwnerReadiness.imported || OwnerReadiness.initialized):
            return Ok(value.database);
          case Ok():
            await value.close();
            return const Err(LegacyImportDeferred());
          case Err(:final failure):
            await value.close();
            return Err(failure);
        }
    }
  }

  Future<Result<_ProjectionStore<T>, LegacyImportFailure>> _open(
    LifecycleAdmission admission, {
    required bool existing,
  }) async {
    final settled = Completer<void>();
    T? database;
    final handle = admission.track(() async {
      await settled.future;
      await database?.close();
    });
    var published = false;
    try {
      switch (await openExecutor(existing: existing)) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          final selected = create(value);
          database = selected;
          await selected
              .customSelect('SELECT 1 FROM $destinationTable LIMIT 1')
              .get();
          published = true;
          return Ok(_ProjectionStore(selected, handle));
      }
    } on SqliteException {
      return const Err(LegacyImportUnavailable());
    } finally {
      settled.complete();
      if (!published) await handle.close();
    }
  }

  Future<Result<OwnerReadiness, LegacyImportFailure>> _readiness(
    T database,
  ) async {
    final imported = await hasLegacyImportReceipt(database, _imported);
    final fresh = await hasLegacyImportReceipt(database, _fresh);
    return switch ((imported, fresh)) {
      (Ok(value: true), Ok(value: true)) => const Err(
        LegacyImportVerificationFailed(),
      ),
      (Ok(value: true), Ok(value: false)) => const Ok(OwnerReadiness.imported),
      (Ok(value: false), Ok(value: true)) => const Ok(
        OwnerReadiness.initialized,
      ),
      (Ok(value: false), Ok(value: false)) => const Ok(OwnerReadiness.pending),
      _ => const Err(LegacyImportUnavailable()),
    };
  }
}

final class _ProjectionStore<T extends GeneratedDatabase> {
  final T database;
  final LifecycleHandle _handle;

  const _ProjectionStore(this.database, this._handle);

  Future<void> close() => _handle.close();
}

final class _PreparedProjection<T extends GeneratedDatabase>
    implements PreparedOwner {
  final WalletColumnProjection<T> _projection;
  final _ProjectionStore<T> _store;

  _PreparedProjection(this._projection, this._store);

  @override
  Future<Result<void, LegacyImportFailure>> importLegacy(LegacySource source) {
    if (source.schemaVersion != 16) {
      return Future.value(const Err(LegacySourceSchemaMismatch()));
    }
    final column = _projection.column;
    final table = _projection.destinationTable;
    final database = _store.database;
    return importLegacyDatabase(
      id: _projection._imported,
      source: source.file,
      sourceSchemaVersion: source.schemaVersion,
      destination: database,
      copyAndVerify: (legacy) async {
        final fresh = await hasLegacyImportReceipt(
          database,
          _projection._fresh,
        );
        if (fresh is! Ok<bool, LegacyImportFailure> || fresh.value) {
          return false;
        }
        final before = legacy.select(
          'SELECT id, $column FROM wallet_metadatas ORDER BY id',
        );
        for (final row in before) {
          await database.customStatement(
            'INSERT INTO $table (wallet_id, $column) VALUES (?, ?)',
            [row['id'], row[column]],
          );
        }
        final after = await database
            .customSelect(
              'SELECT wallet_id, $column FROM $table ORDER BY wallet_id',
            )
            .get();
        if (before.length != after.length) return false;
        for (var index = 0; index < before.length; index++) {
          if (before[index]['id'] != after[index].data['wallet_id'] ||
              before[index][column] != after[index].data[column]) {
            return false;
          }
        }
        return true;
      },
    );
  }

  @override
  Future<Result<void, LegacyImportFailure>> initializeFresh() async {
    final database = _store.database;
    try {
      return await database.transaction(() async {
        switch (await receipt()) {
          case Err(:final failure):
            return Err(failure);
          case Ok(value: OwnerReadiness.initialized):
            return const Ok(null);
          case Ok(value: OwnerReadiness.imported):
            return const Err(LegacyImportVerificationFailed());
          case Ok(value: OwnerReadiness.pending):
            final rows = await database
                .customSelect(
                  'SELECT 1 FROM ${_projection.destinationTable} LIMIT 1',
                )
                .get();
            if (rows.isNotEmpty) {
              return const Err(LegacyImportVerificationFailed());
            }
            await database.customStatement(
              'INSERT INTO legacy_import_receipts (id) VALUES (?)',
              [_projection._fresh],
            );
            return const Ok(null);
        }
      });
    } on SqliteException {
      return const Err(LegacyImportUnavailable());
    }
  }

  @override
  Future<Result<OwnerReadiness, LegacyImportFailure>> receipt() =>
      _projection._readiness(_store.database);

  @override
  Future<Result<void, LegacyImportFailure>> close() async {
    try {
      await _store.close();
      return const Ok(null);
    } on Exception {
      return const Err(LegacyImportUnavailable());
    }
  }
}
