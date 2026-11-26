import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import 'preferences_database.dart';
import 'preferences_store.dart';

const preferencesImportReceipt = 'split-v1/preferences';
const preferencesFreshReceipt = 'fresh-v1/preferences';

final class PreferencesImport implements LegacyImportParticipant {
  final File file;
  final String defaultRecoverBullServerUrl;
  final Future<
    Result<({String sourceUrl, bool permissionGranted})?, LegacyImportFailure>
  >
  Function()?
  readStandalonePermission;
  final DatabaseKeys? testingKeys;
  final Future<void> Function(String)? checkpoint;

  PreferencesImport({
    required this.file,
    required this.defaultRecoverBullServerUrl,
    this.readStandalonePermission,
    this.testingKeys,
    this.checkpoint,
  });

  @override
  String get ownerId => 'preferences';

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
    final store = await PreferencesStore.open(
      file,
      admission,
      existing: false,
      testingKeys: testingKeys,
    );
    return switch (store) {
      Ok(:final value) => Ok(
        _PreparedPreferences(
          value,
          defaultRecoverBullServerUrl,
          readStandalonePermission,
          checkpoint,
        ),
      ),
      Err(failure: DatabaseNotReady()) => const Err(LegacyImportDeferred()),
      Err(failure: DatabaseKeyUnavailable(reason: DatabaseKeyProblem.locked)) =>
        const Err(LegacyImportDeferred()),
      Err() => const Err(LegacyImportUnavailable()),
    };
  }

  @override
  Future<Result<OwnerReadiness, LegacyImportFailure>> inspect(
    LifecycleAdmission admission,
  ) async {
    final opened = await PreferencesStore.open(
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
    final store = (opened as Ok<PreferencesStore, DatabaseOpenFailure>).value;
    try {
      return await readPreferencesReadiness(store.database);
    } finally {
      await store.handle.close();
    }
  }
}

Future<Result<OwnerReadiness, LegacyImportFailure>> readPreferencesReadiness(
  PreferencesDatabase database,
) async {
  try {
    final receipts = await database
        .customSelect('SELECT id FROM legacy_import_receipts LIMIT 2')
        .get();
    if (receipts.isEmpty) return const Ok(OwnerReadiness.pending);
    if (receipts.length != 1) {
      return const Err(LegacyImportVerificationFailed());
    }
    return switch (receipts.single.data['id']) {
      preferencesImportReceipt => const Ok(OwnerReadiness.imported),
      preferencesFreshReceipt => const Ok(OwnerReadiness.initialized),
      _ => const Err(LegacyImportVerificationFailed()),
    };
  } on Exception {
    return const Err(LegacyImportUnavailable());
  }
}

final class _PreparedPreferences implements PreparedOwner {
  final PreferencesStore store;
  final String defaultRecoverBullServerUrl;
  final Future<
    Result<({String sourceUrl, bool permissionGranted})?, LegacyImportFailure>
  >
  Function()?
  readStandalonePermission;
  final Future<void> Function(String)? checkpoint;

  const _PreparedPreferences(
    this.store,
    this.defaultRecoverBullServerUrl,
    this.readStandalonePermission,
    this.checkpoint,
  );

  @override
  Future<Result<void, LegacyImportFailure>> importLegacy(
    LegacySource source,
  ) async {
    try {
      return await _importLegacy(source);
    } on Exception {
      return const Err(LegacyImportUnavailable());
    }
  }

  Future<Result<void, LegacyImportFailure>> _importLegacy(
    LegacySource source,
  ) async {
    final readiness = await receipt();
    if (readiness case Err(:final failure)) return Err(failure);
    if (readiness case Ok(value: OwnerReadiness.initialized)) {
      return const Err(LegacyImportVerificationFailed());
    }
    LegacyImportFailure? consentFailure;
    final result = await importLegacyDatabase(
      id: preferencesImportReceipt,
      source: source.file,
      sourceSchemaVersion: source.schemaVersion,
      destination: store.database,
      copyAndVerify: (source) async {
        final fresh = await hasLegacyImportReceipt(
          store.database,
          preferencesFreshReceipt,
        );
        if (fresh is! Ok<bool, LegacyImportFailure> || fresh.value) {
          return false;
        }
        if (!await _isEmpty()) return false;
        final consent = await _readStandaloneConsent();
        if (consent case Err(:final failure)) {
          consentFailure = failure;
          return false;
        }
        for (final entry in _columns.entries) {
          final table = entry.key;
          final columns = entry.value;
          // Consent is scoped to the accepted server. Project the permission
          // without ever copying the historical URL into the destination.
          final oldRows = table == 'recoverbull'
              ? source.select(
                  'SELECT id, CASE WHEN url COLLATE BINARY = ? '
                  'THEN is_permission_granted ELSE 0 END AS is_permission_granted '
                  'FROM recoverbull ORDER BY id',
                  [defaultRecoverBullServerUrl],
                )
              : source.select('SELECT $columns FROM $table ORDER BY id');
          final sequences = source.select(
            'SELECT seq FROM sqlite_sequence WHERE name = ?',
            [table],
          );
          if (sequences.length > 1) return false;
          final sequence = sequences.isEmpty ? null : sequences.single['seq'];
          if (sequences.isNotEmpty && (sequence is! int || sequence < 0)) {
            return false;
          }
          final highest = oldRows.fold<int>(0, (value, row) {
            final id = row['id'] as int;
            return id > value ? id : value;
          });
          if (oldRows.isNotEmpty && (sequence is! int || sequence < highest)) {
            return false;
          }
          final placeholders = List.filled(columns.split(',').length, '?');
          for (final row in oldRows) {
            await store.database.customStatement(
              'INSERT INTO $table ($columns) VALUES (${placeholders.join(',')})',
              row.values.toList(),
            );
          }
          await checkpoint?.call('import-rows-$table');
          // Strict inserts may have created a lower sequence. Restore only the
          // frozen source high-water, never just the largest surviving row ID.
          await store.database.customStatement(
            'DELETE FROM sqlite_sequence WHERE name = ?',
            [table],
          );
          if (sequence != null) {
            await store.database.customStatement(
              'INSERT INTO sqlite_sequence (name, seq) VALUES (?, ?)',
              [table, sequence],
            );
          }
          await checkpoint?.call('import-sequence-$table');
          final copied = await store.database
              .customSelect('SELECT $columns FROM $table ORDER BY id')
              .get();
          final copiedSequence = await _sequence(table);
          if (!_sameRawValues(
                oldRows.map((row) => row.values.toList()).toList(),
                copied.map((row) => row.data.values.toList()).toList(),
              ) ||
              !_sameRawValues(
                sequences.map((row) => row.values.toList()).toList(),
                copiedSequence,
              )) {
            return false;
          }
        }
        if (!await _writeStandaloneConsent(
          (consent as Ok<bool?, LegacyImportFailure>).value,
        )) {
          return false;
        }
        await checkpoint?.call('import-verify');
        return true;
      },
    );
    if (consentFailure case final failure?) return Err(failure);
    if (result is Ok<void, LegacyImportFailure>) {
      await checkpoint?.call('import-commit');
    }
    return result;
  }

  static const _columns = {
    'settings': 'id,environment,bitcoin_unit,start_amounts_in_fiat,language,currency,hide_amounts,is_superuser,is_dev_mode_enabled,use_tor_proxy,tor_proxy_port,tor_transport_mode,last_successful_tor_transport,theme_mode,is_error_reporting_enabled,screen_capture_protection_enabled',
    'recoverbull': 'id,is_permission_granted',
  };

  Future<List<List<Object?>>> _sequence(String table) async =>
      (await store.database
              .customSelect(
                'SELECT seq FROM sqlite_sequence WHERE name = ?',
                variables: [Variable(table)],
              )
              .get())
          .map((row) => row.data.values.toList())
          .toList();

  Future<bool> _isEmpty() async {
    for (final table in _columns.keys) {
      if ((await store.database
                  .customSelect('SELECT 1 FROM $table LIMIT 1')
                  .get())
              .isNotEmpty ||
          (await _sequence(table)).isNotEmpty) {
        return false;
      }
    }
    return (await store.database
            .customSelect(
              'SELECT 1 FROM recoverbull_permission_overrides LIMIT 1',
            )
            .get())
        .isEmpty;
  }

  Future<Result<bool?, LegacyImportFailure>> _readStandaloneConsent() async {
    final read = readStandalonePermission;
    if (read == null) return const Ok(null);
    return (await read()).map(
      (consent) => consent == null
          ? null
          : consent.permissionGranted &&
                consent.sourceUrl == defaultRecoverBullServerUrl,
    );
  }

  Future<bool> _writeStandaloneConsent(bool? consent) async {
    if (consent == null) return true;
    final row = ['default', consent ? 1 : 0];
    await store.database.customStatement(
      'INSERT INTO recoverbull_permission_overrides '
      '(family, is_permission_granted) VALUES (?, ?)',
      row,
    );
    final rows = await store.database
        .customSelect(
          'SELECT family, is_permission_granted '
          'FROM recoverbull_permission_overrides ORDER BY family',
        )
        .get();
    return _sameRawValues([
      row,
    ], rows.map((row) => row.data.values.toList()).toList());
  }

  @override
  Future<Result<void, LegacyImportFailure>> initializeFresh() async {
    try {
      await store.database.customSelect('SELECT 1').get();
      await checkpoint?.call('fresh-schema');
      final result = await store.database
          .transaction<Result<void, LegacyImportFailure>>(() async {
            switch (await receipt()) {
              case Err(:final failure):
                return Err(failure);
              case Ok(value: OwnerReadiness.initialized):
                return const Ok(null);
              case Ok(value: OwnerReadiness.pending):
                break;
              case Ok():
                return const Err(LegacyImportVerificationFailed());
            }
            if (!await _isEmpty()) {
              return const Err(LegacyImportVerificationFailed());
            }
            final consent = await _readStandaloneConsent();
            if (consent case Err(:final failure)) return Err(failure);
            final defaults = <String, List<Object?>>{
              'settings': [
                1,
                'mainnet',
                'sats',
                0,
                'unitedStatesEnglish',
                'USD',
                0,
                0,
                0,
                0,
                9050,
                'automatic',
                null,
                'system',
                0,
                1,
              ],
              'recoverbull': [1, 0],
            };
            for (final entry in defaults.entries) {
              final columns = _columns[entry.key];
              if (columns == null) throw const _FreshConflict();
              await store.database.customStatement(
                'INSERT INTO ${entry.key} ($columns) VALUES (${List.filled(entry.value.length, '?').join(',')})',
                entry.value,
              );
              final rows = await store.database
                  .customSelect('SELECT $columns FROM ${entry.key} ORDER BY id')
                  .get();
              if (!_sameRawValues(
                    rows.map((row) => row.data.values.toList()).toList(),
                    [entry.value],
                  ) ||
                  !_sameRawValues(await _sequence(entry.key), [
                    [1],
                  ])) {
                throw const _FreshConflict();
              }
            }
            if (!await _writeStandaloneConsent(
              (consent as Ok<bool?, LegacyImportFailure>).value,
            )) {
              throw const _FreshConflict();
            }
            await checkpoint?.call('fresh-seeds');
            await store.database.customStatement(
              'INSERT INTO legacy_import_receipts (id) VALUES (?)',
              [preferencesFreshReceipt],
            );
            await checkpoint?.call('fresh-receipt');
            return const Ok(null);
          });
      if (result case Ok()) await checkpoint?.call('fresh-commit');
      return result;
    } on _FreshConflict {
      return const Err(LegacyImportVerificationFailed());
    } on Exception {
      return const Err(LegacyImportUnavailable());
    }
  }

  @override
  Future<Result<OwnerReadiness, LegacyImportFailure>> receipt() =>
      readPreferencesReadiness(store.database);

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

bool _sameRawValues(Object? a, Object? b) {
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (!_sameRawValues(a[index], b[index])) return false;
    }
    return true;
  }
  // Dart compares equal integer and real values as equal; SQLite does not
  // store them as the same type. Keep the physical type in the comparison.
  return a.runtimeType == b.runtimeType && a == b;
}

final class _FreshConflict implements Exception {
  const _FreshConflict();
}
