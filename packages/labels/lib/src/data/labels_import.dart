import 'dart:convert';
import 'dart:io';

import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException, Database;

import 'labels_database.dart';
import 'labels_store.dart';

const labelsImportReceipt = 'split-v1/labels';
const labelsFreshReceipt = 'fresh-v1/labels';

final class LabelsImport implements LegacyImportParticipant {
  final File file;
  final DatabaseKeys? _testingKeys;
  final Future<void> Function(String)? _checkpoint;

  LabelsImport({required this.file}) : _testingKeys = null, _checkpoint = null;

  LabelsImport._testing(this.file, this._testingKeys, this._checkpoint);

  @override
  String get ownerId => 'labels';

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
  ) async {
    final result = await LabelsStore.open(
      file,
      admission,
      existing: false,
      testingKeys: _testingKeys,
    );
    return switch (result) {
      Ok(:final value) => Ok(_PreparedLabels(value, _checkpoint)),
      Err(:final failure) => Err(_openFailure(failure)),
    };
  }

  @override
  Future<Result<OwnerReadiness, LegacyImportFailure>> inspect(
    LifecycleAdmission admission,
  ) async {
    final opened = await LabelsStore.open(
      file,
      admission,
      existing: true,
      testingKeys: _testingKeys,
    );
    if (opened case Err(:final failure)) return Err(_openFailure(failure));
    final store = (opened as Ok<LabelsStore, DatabaseOpenFailure>).value;
    try {
      return await readLabelsReadiness(store.database);
    } finally {
      await store.handle.close();
    }
  }
}

// Internal harness only; deliberately absent from the migration entry library.
@visibleForTesting
LabelsImport createLabelsImportForTesting({
  required File file,
  required DatabaseKeys keys,
  Future<void> Function(String)? checkpoint,
}) => LabelsImport._testing(file, keys, checkpoint);

LegacyImportFailure _openFailure(DatabaseOpenFailure failure) =>
    failure is DatabaseNotReady ||
        failure is DatabaseKeyUnavailable &&
            failure.reason == DatabaseKeyProblem.locked
    ? const LegacyImportDeferred()
    : const LegacyImportUnavailable();

Future<Result<OwnerReadiness, LegacyImportFailure>> readLabelsReadiness(
  LabelsDatabase database,
) async {
  try {
    final rows = await database
        .customSelect('SELECT id FROM legacy_import_receipts')
        .get();
    if (rows.isEmpty) return const Ok(OwnerReadiness.pending);
    if (rows.length != 1) return const Err(LegacyImportVerificationFailed());
    return switch (rows.single.data['id']) {
      labelsImportReceipt => const Ok(OwnerReadiness.imported),
      labelsFreshReceipt => const Ok(OwnerReadiness.initialized),
      _ => const Err(LegacyImportVerificationFailed()),
    };
  } on DriftRemoteException {
    return const Err(LegacyImportUnavailable());
  } on SqliteException {
    return const Err(LegacyImportUnavailable());
  }
}

const _columns = {
  'labels': 'id,label,reference,type,origin',
  'frozen_utxos': 'wallet_id,tx_id,vout',
};

final class _PreparedLabels implements PreparedOwner {
  final LabelsStore store;
  final Future<void> Function(String)? checkpoint;

  const _PreparedLabels(this.store, this.checkpoint);

  @override
  Future<Result<void, LegacyImportFailure>> importLegacy(
    LegacySource source,
  ) async {
    try {
      final result = await store.database.transaction(() async {
        final ready = await receipt();
        if (ready case Ok(value: OwnerReadiness.imported)) {
          return const Ok<void, LegacyImportFailure>(null);
        }
        if (ready case Err(:final failure)) {
          return Err<void, LegacyImportFailure>(failure);
        }
        if (ready case Ok(value: OwnerReadiness.initialized)) {
          return const Err<void, LegacyImportFailure>(
            LegacyImportVerificationFailed(),
          );
        }
        await _requireEmpty();
        return importLegacyDatabase(
          id: labelsImportReceipt,
          source: source.file,
          sourceSchemaVersion: source.schemaVersion,
          destination: store.database,
          copyAndVerify: (source) async {
            final sequence = readLegacyLabelsSequence(source);
            for (final entry in _columns.entries) {
              final columns = entry.value;
              final rows = source.select(
                'SELECT $columns FROM ${entry.key} ORDER BY $columns',
              );
              for (final row in rows) {
                await store.database.customStatement(
                  'INSERT INTO ${entry.key} ($columns) VALUES (${List.filled(columns.split(',').length, '?').join(',')})',
                  row.values.toList(),
                );
              }
              await checkpoint?.call('import-rows');
              final copied = await store.database
                  .customSelect(
                    'SELECT $columns FROM ${entry.key} ORDER BY $columns',
                  )
                  .get();
              if (jsonEncode(rows.map((row) => row.values.toList()).toList()) !=
                  jsonEncode(
                    copied.map((row) => row.data.values.toList()).toList(),
                  )) {
                return false;
              }
            }
            await store.database.customStatement(
              "DELETE FROM sqlite_sequence WHERE name = 'labels'",
            );
            if (sequence case final value?) {
              await store.database.customStatement(
                "INSERT INTO sqlite_sequence (name,seq) VALUES ('labels',?)",
                [value],
              );
            }
            await checkpoint?.call('import-sequence');
            if (await readLabelsSequence(store.database) != sequence) {
              return false;
            }
            await checkpoint?.call('import-verify');
            return true;
          },
        );
      });
      if (result is Ok<void, LegacyImportFailure>) {
        await checkpoint?.call('import-commit');
      }
      return result;
    } on _Conflict {
      return const Err(LegacyImportVerificationFailed());
    } on DriftRemoteException {
      return const Err(LegacyImportUnavailable());
    } on SqliteException {
      return const Err(LegacyImportUnavailable());
    }
  }

  Future<void> _requireEmpty() async {
    for (final table in _columns.keys) {
      if ((await store.database
              .customSelect('SELECT 1 FROM $table LIMIT 1')
              .get())
          .isNotEmpty) {
        throw const _Conflict();
      }
    }
    final sequence = await readLabelsSequence(store.database);
    if (sequence != null && sequence != 0) throw const _Conflict();
  }

  @override
  Future<Result<void, LegacyImportFailure>> initializeFresh() async {
    try {
      await store.database.customSelect('SELECT 1').get();
      await checkpoint?.call('fresh-schema');
      await store.database.transaction(() async {
        final ready = await receipt();
        if (ready case Ok(value: OwnerReadiness.initialized)) return;
        if (ready is! Ok<OwnerReadiness, LegacyImportFailure> ||
            ready.value != OwnerReadiness.pending) {
          throw const _Conflict();
        }
        await _requireEmpty();
        await checkpoint?.call('fresh-seeds');
        await store.database.customStatement(
          'INSERT INTO legacy_import_receipts (id) VALUES (?)',
          [labelsFreshReceipt],
        );
        await checkpoint?.call('fresh-receipt');
      });
      await checkpoint?.call('fresh-commit');
      return const Ok(null);
    } on _Conflict {
      return const Err(LegacyImportVerificationFailed());
    } on FileSystemException {
      return const Err(LegacyImportUnavailable());
    } on DriftRemoteException {
      return const Err(LegacyImportUnavailable());
    } on SqliteException {
      return const Err(LegacyImportUnavailable());
    }
  }

  @override
  Future<Result<OwnerReadiness, LegacyImportFailure>> receipt() =>
      readLabelsReadiness(store.database);

  @override
  Future<Result<void, LegacyImportFailure>> close() async {
    try {
      await store.handle.close();
      return const Ok(null);
    } on Exception {
      return const Err(LegacyImportUnavailable());
    }
  }
}

final class _Conflict implements Exception {
  const _Conflict();
}

int? _validateSequence(
  List<Map<String, Object?>> sequence,
  List<Map<String, Object?>> count,
) {
  final rowCount = count.single['count'];
  final maximum = count.single['maximum'];
  if (rowCount is! int || maximum is! int) throw const _Conflict();
  if (sequence.isEmpty) {
    if (rowCount != 0) throw const _Conflict();
    return null;
  }
  if (sequence.length != 1) throw const _Conflict();
  final row = sequence.single;
  final value = row['seq'];
  if (row['kind'] != 'integer' ||
      value is! int ||
      value < 0 ||
      value < maximum) {
    throw const _Conflict();
  }
  return value;
}

const _sequenceSql =
    "SELECT seq, typeof(seq) AS kind FROM sqlite_sequence WHERE name = 'labels'";
const _maximumSql =
    'SELECT COUNT(*) AS count, COALESCE(MAX(CASE WHEN id > 0 THEN id ELSE 0 END),0) AS maximum FROM labels';

int? readLegacyLabelsSequence(Database source) => _validateSequence(
  source
      .select(_sequenceSql)
      .map((row) => Map<String, Object?>.from(row))
      .toList(),
  source
      .select(_maximumSql)
      .map((row) => Map<String, Object?>.from(row))
      .toList(),
);

Future<int?> readLabelsSequence(LabelsDatabase database) async =>
    _validateSequence(
      (await database.customSelect(_sequenceSql).get())
          .map((row) => row.data)
          .toList(),
      (await database.customSelect(_maximumSql).get())
          .map((row) => row.data)
          .toList(),
    );
