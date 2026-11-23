import 'dart:convert';
import 'dart:io';

import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../domain/electrum_default_endpoints.dart';
import 'electrum_database.dart';
import 'electrum_store.dart';

const electrumImportReceipt = 'split-v1/electrum';
const electrumFreshReceipt = 'fresh-v1/electrum';

final class ElectrumImport implements LegacyImportParticipant {
  final File file;
  final DatabaseKeys? _testingKeys;
  final Future<void> Function(String)? _checkpoint;

  ElectrumImport({required this.file})
    : _testingKeys = null,
      _checkpoint = null;

  ElectrumImport._testing(this.file, this._testingKeys, this._checkpoint);

  @override
  String get ownerId => 'electrum';

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
    final result = await ElectrumStore.open(
      file,
      admission,
      existing: false,
      testingKeys: _testingKeys,
    );
    return switch (result) {
      Ok(:final value) => Ok(_PreparedElectrum(value, _checkpoint)),
      Err(:final failure) => Err(_openFailure(failure)),
    };
  }

  @override
  Future<Result<OwnerReadiness, LegacyImportFailure>> inspect(
    RuntimeAdmission admission,
  ) async {
    final opened = await ElectrumStore.open(
      file,
      admission,
      existing: true,
      testingKeys: _testingKeys,
    );
    if (opened case Err(:final failure)) return Err(_openFailure(failure));
    final store = (opened as Ok<ElectrumStore, DatabaseOpenFailure>).value;
    try {
      return await readElectrumReadiness(store.database);
    } finally {
      await store.handle.close();
    }
  }
}

// Internal harness only; deliberately absent from the migration entry library.
@visibleForTesting
ElectrumImport createElectrumImportForTesting({
  required File file,
  required DatabaseKeys keys,
  Future<void> Function(String)? checkpoint,
}) => ElectrumImport._testing(file, keys, checkpoint);

LegacyImportFailure _openFailure(DatabaseOpenFailure failure) =>
    failure is DatabaseNotReady ||
        failure is DatabaseKeyUnavailable &&
            failure.reason == DatabaseKeyProblem.locked
    ? const LegacyImportDeferred()
    : const LegacyImportUnavailable();

Future<Result<OwnerReadiness, LegacyImportFailure>> readElectrumReadiness(
  ElectrumDatabase database,
) async {
  try {
    final rows = await database
        .customSelect('SELECT id FROM legacy_import_receipts')
        .get();
    if (rows.isEmpty) return const Ok(OwnerReadiness.pending);
    if (rows.length != 1) return const Err(LegacyImportVerificationFailed());
    return switch (rows.single.data['id']) {
      electrumImportReceipt => const Ok(OwnerReadiness.imported),
      electrumFreshReceipt => const Ok(OwnerReadiness.initialized),
      _ => const Err(LegacyImportVerificationFailed()),
    };
  } on DriftRemoteException {
    return const Err(LegacyImportUnavailable());
  } on SqliteException {
    return const Err(LegacyImportUnavailable());
  }
}

const _columns = {
  'electrum_servers': 'url,network,priority,is_custom',
  'electrum_settings': 'network,validate_domain,stop_gap,timeout,retry,socks5',
  'transactions': 'txid,version,size,vsize,locktime,vin,vout,blockhash,height,confirmations,time,blocktime',
};

final class _PreparedElectrum implements PreparedOwner {
  final ElectrumStore store;
  final Future<void> Function(String)? checkpoint;

  const _PreparedElectrum(this.store, this.checkpoint);

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
          id: electrumImportReceipt,
          source: source.file,
          sourceSchemaVersion: source.schemaVersion,
          destination: store.database,
          copyAndVerify: (source) async {
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
        for (final row in _servers) {
          await store.database.customStatement(
            'INSERT INTO electrum_servers (url,network,priority,is_custom) VALUES (?,?,?,?)',
            row,
          );
        }
        for (final network in _networks) {
          await store.database.customStatement(
            'INSERT INTO electrum_settings (network,validate_domain,stop_gap,timeout,retry,socks5) VALUES (?,1,20,5,5,NULL)',
            [network],
          );
        }
        final expected = <String, List<List<Object?>>>{
          'electrum_servers': _servers,
          'electrum_settings': [
            for (final network in _networks) [network, 1, 20, 5, 5, null],
          ],
          'transactions': [],
        };
        for (final entry in _columns.entries) {
          final actual = await store.database
              .customSelect('SELECT ${entry.value} FROM ${entry.key}')
              .get();
          final rows =
              actual.map((row) => jsonEncode(row.data.values.toList())).toList()
                ..sort();
          final seeds = expected[entry.key];
          if (seeds == null) throw const _Conflict();
          final encoded = seeds.map(jsonEncode).toList()..sort();
          if (jsonEncode(rows) != jsonEncode(encoded)) throw const _Conflict();
        }
        await checkpoint?.call('fresh-seeds');
        await store.database.customStatement(
          'INSERT INTO legacy_import_receipts (id) VALUES (?)',
          [electrumFreshReceipt],
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
      readElectrumReadiness(store.database);

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

const _networks = [
  'bitcoinMainnet',
  'bitcoinTestnet',
  'liquidMainnet',
  'liquidTestnet',
  'bitcoinRegtest',
];
const _servers = <List<Object?>>[
  [ElectrumDefaultEndpoints.fulcrumElectrumUrl, 'bitcoinMainnet', 0, 0],
  [ElectrumDefaultEndpoints.bbElectrumUrl, 'bitcoinMainnet', 1, 0],
  [ElectrumDefaultEndpoints.bbLiquidElectrumUrlPath, 'liquidMainnet', 0, 0],
  [ElectrumDefaultEndpoints.publicElectrumUrl, 'bitcoinMainnet', 2, 0],
  [ElectrumDefaultEndpoints.publicLiquidElectrumUrlPath, 'liquidMainnet', 1, 0],
  [ElectrumDefaultEndpoints.publicElectrumTestUrl, 'bitcoinTestnet', 0, 0],
  [
    ElectrumDefaultEndpoints.publicliquidElectrumTestUrlPath,
    'liquidTestnet',
    0,
    0,
  ],
  ['tcp://127.0.0.1:50000', 'bitcoinRegtest', 0, 0],
];

final class _Conflict implements Exception {
  const _Conflict();
}
