import 'dart:convert';
import 'dart:io';

import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import 'mempool_database.dart';
import 'mempool_seeds.dart';
import 'mempool_store.dart';

const mempoolImportReceipt = 'split-v1/mempool';
const mempoolFreshReceipt = 'fresh-v1/mempool';

final class MempoolImport implements LegacyImportParticipant {
  final File file;
  final List<String> defaultServers;
  final DatabaseKeys? testingKeys;
  final Future<void> Function(String)? checkpoint;

  MempoolImport({
    required this.file,
    required List<String> defaultServers,
    this.testingKeys,
    this.checkpoint,
  }) : defaultServers = List.unmodifiable(defaultServers) {
    if (defaultServers.length != 4) {
      throw ArgumentError('Four networks required');
    }
  }

  @override
  String get ownerId => 'mempool';

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
    final store = await MempoolStore.open(
      file,
      admission,
      existing: false,
      testingKeys: testingKeys,
    );
    return switch (store) {
      Ok(:final value) => Ok(
        _PreparedMempool(value, defaultServers, checkpoint),
      ),
      Err(failure: DatabaseNotReady()) => const Err(LegacyImportDeferred()),
      Err(failure: DatabaseKeyUnavailable(reason: DatabaseKeyProblem.locked)) =>
        const Err(LegacyImportDeferred()),
      Err() => const Err(LegacyImportUnavailable()),
    };
  }

  @override
  Future<Result<OwnerReadiness, LegacyImportFailure>> inspect(
    RuntimeAdmission admission,
  ) async {
    final opened = await MempoolStore.open(
      file,
      admission,
      existing: true,
      testingKeys: testingKeys,
    );
    if (opened case Err(:final failure)) {
      return failure is DatabaseNotReady ||
              failure is DatabaseKeyUnavailable &&
                  failure.reason == DatabaseKeyProblem.locked
          ? const Err(LegacyImportDeferred())
          : const Err(LegacyImportUnavailable());
    }
    final store = (opened as Ok<MempoolStore, DatabaseOpenFailure>).value;
    try {
      return await readMempoolReadiness(store.database);
    } finally {
      await store.handle.close();
    }
  }
}

Future<Result<OwnerReadiness, LegacyImportFailure>> readMempoolReadiness(
  MempoolDatabase database,
) async {
  final imported = await hasLegacyImportReceipt(database, mempoolImportReceipt);
  final fresh = await hasLegacyImportReceipt(database, mempoolFreshReceipt);
  if (imported case Ok(value: final hasImport)) {
    if (fresh case Ok(value: final hasFresh)) {
      if (hasImport && hasFresh) {
        return const Err(LegacyImportVerificationFailed());
      }
      return Ok(
        hasImport
            ? OwnerReadiness.imported
            : hasFresh
            ? OwnerReadiness.initialized
            : OwnerReadiness.pending,
      );
    }
  }
  return const Err(LegacyImportUnavailable());
}

final class _PreparedMempool implements PreparedOwner {
  final MempoolStore store;
  final List<String> defaults;
  final Future<void> Function(String)? checkpoint;

  const _PreparedMempool(this.store, this.defaults, this.checkpoint);

  @override
  Future<Result<void, LegacyImportFailure>> importLegacy(
    LegacySource source,
  ) async {
    final result = await importLegacyDatabase(
      id: mempoolImportReceipt,
      source: source.file,
      sourceSchemaVersion: source.schemaVersion,
      destination: store.database,
      copyAndVerify: (source) async {
        final fresh = await hasLegacyImportReceipt(
          store.database,
          mempoolFreshReceipt,
        );
        if (fresh is! Ok<bool, LegacyImportFailure> || fresh.value) {
          return false;
        }
        for (final entry in _columns.entries) {
          final table = entry.key;
          final columns = entry.value;
          final oldRows = source.select(
            'SELECT $columns FROM $table ORDER BY $columns',
          );
          final count = columns.split(',').length;
          for (final row in oldRows) {
            await store.database.customStatement(
              'INSERT INTO $table ($columns) VALUES (${List.filled(count, '?').join(',')})',
              row.values.toList(),
            );
          }
          await checkpoint?.call('import-rows');
          final copied = await store.database
              .customSelect('SELECT $columns FROM $table ORDER BY $columns')
              .get();
          if (jsonEncode(oldRows.map((row) => row.values.toList()).toList()) !=
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
    if (result is Ok<void, LegacyImportFailure>) {
      await checkpoint?.call('import-commit');
    }
    return result;
  }

  static const _columns = {
    'mempool_servers': 'url,is_testnet,is_liquid,is_custom,enable_ssl',
    'mempool_settings': 'network,use_for_fee_estimation',
  };

  @override
  Future<Result<void, LegacyImportFailure>> initializeFresh() async {
    try {
      await store.database.customSelect('SELECT 1').get();
      await checkpoint?.call('fresh-schema');
      await store.database.transaction(() async {
        final readiness = await receipt();
        if (readiness case Ok(value: OwnerReadiness.initialized)) return;
        if (readiness is! Ok<OwnerReadiness, LegacyImportFailure> ||
            readiness.value != OwnerReadiness.pending) {
          throw const _FreshConflict();
        }
        for (final table in _columns.keys) {
          final rows = await store.database
              .customSelect('SELECT 1 FROM $table LIMIT 1')
              .get();
          if (rows.isNotEmpty) throw const _FreshConflict();
        }
        await MempoolSeeds.seedDefaultServers(
          store.database,
          bitcoinMainnet: defaults[0],
          bitcoinTestnet: defaults[1],
          liquidMainnet: defaults[2],
          liquidTestnet: defaults[3],
        );
        await MempoolSeeds.seedDefaultSettings(store.database);
        final servers = await store.database
            .customSelect('SELECT * FROM mempool_servers')
            .get();
        final settings = await store.database
            .customSelect('SELECT * FROM mempool_settings')
            .get();
        if (servers.length != 4 ||
            settings.length != 4 ||
            settings.any(
              (row) => row.read<int>('use_for_fee_estimation') != 1,
            )) {
          throw const _FreshConflict();
        }
        for (var index = 0; index < defaults.length; index++) {
          if (!servers.any(
            (row) =>
                row.read<String>('url') == defaults[index] &&
                row.read<int>('is_testnet') == index % 2 &&
                row.read<int>('is_liquid') == index ~/ 2 &&
                row.read<int>('is_custom') == 0 &&
                row.read<int>('enable_ssl') == 1,
          )) {
            throw const _FreshConflict();
          }
        }
        await checkpoint?.call('fresh-seeds');
        await store.database.customStatement(
          'INSERT INTO legacy_import_receipts (id) VALUES (?)',
          [mempoolFreshReceipt],
        );
        await checkpoint?.call('fresh-receipt');
      });
      await checkpoint?.call('fresh-commit');
      return const Ok(null);
    } on _FreshConflict {
      return const Err(LegacyImportVerificationFailed());
    } on SqliteException {
      return const Err(LegacyImportUnavailable());
    }
  }

  @override
  Future<Result<OwnerReadiness, LegacyImportFailure>> receipt() =>
      readMempoolReadiness(store.database);

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

final class _FreshConflict implements Exception {
  const _FreshConflict();
}
