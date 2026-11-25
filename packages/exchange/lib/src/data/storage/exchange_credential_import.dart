import 'dart:io';

import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import 'exchange_database.dart';
import 'exchange_readiness.dart';
import 'exchange_store.dart';

typedef _Records = ExchangeApiRecords;
typedef _BasicAuth = ({int id, String? username, String? password});

/// Uses the fake keystore installed on the test isolate, not a platform worker.
ExchangeCredentialImport exchangeCredentialImportForTesting({
  required File file,
  required Secrets secrets,
}) => ExchangeCredentialImport._(
  file,
  secrets.exchangeKeychain,
  secrets.databaseKeys(module: 'exchange'),
);

/// Copies the two fixed keychain records and the historical Settings rows.
/// The foreground coordinator must freeze both sets of legacy writers before
/// calling any operation under exclusive admission.
final class ExchangeCredentialImport
    implements LegacyImportParticipant, SourceProvenanceCheck {
  final File _file;
  final ExchangeKeychain _legacy;
  final DatabaseKeys? _testingKeys;

  ExchangeCredentialImport({required File file, required Secrets secrets})
    : this._(file, secrets.exchangeKeychain, null);

  const ExchangeCredentialImport._(this._file, this._legacy, this._testingKeys);

  @override
  String get ownerId => 'exchange';

  @override
  Future<bool> hasState() async => [
    '',
    '-wal',
    '-shm',
    '-journal',
    '.retire-pending',
  ].any((suffix) => File('${_file.path}$suffix').existsSync());

  /// A keychain record without a legacy database is iOS residue of an earlier
  /// install. It is never read, written or deleted, so there is nothing to
  /// refuse: the coordinator records the owner as fresh and Exchange starts
  /// signed out.
  @override
  bool get freshWhenInitialFresh => true;

  @override
  Future<Result<void, LegacyImportFailure>> verifyInitialSource(
    ExclusiveAdmission admission, {
    required bool legacySqlitePresent,
  }) async =>
      admission.isOpen ? const Ok(null) : const Err(LegacyImportDeferred());

  Future<Result<ExchangeStore, LegacyImportFailure>> _open(
    LifecycleAdmission admission, {
    required bool existing,
  }) => switch (_testingKeys) {
    final keys? => ExchangeStore.openForTesting(
      file: _file,
      admission: admission,
      keys: keys,
      existing: existing,
    ),
    null => ExchangeStore.open(
      file: _file,
      admission: admission,
      existing: existing,
    ),
  };

  @override
  Future<Result<PreparedOwner, LegacyImportFailure>> prepare(
    ExclusiveAdmission admission,
    OwnerOrigin origin,
  ) async {
    return (await _open(
      admission,
      existing: false,
    )).map((store) => _PreparedExchange(store, _legacy));
  }

  @override
  Future<Result<OwnerReadiness, LegacyImportFailure>> inspect(
    RuntimeAdmission admission,
  ) async {
    switch (await _open(admission, existing: true)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final owner = _PreparedExchange(value, _legacy);
        final receipt = await owner.receipt();
        return switch (await owner.close()) {
          Ok() => receipt,
          Err(:final failure) => Err(failure),
        };
    }
  }
}

Future<Result<_Records, LegacyImportFailure>> _readRecords(
  ExchangeKeychain legacy,
) async {
  final mainnet = await legacy.read(isTestnet: false);
  final testnet = await legacy.read(isTestnet: true);
  return switch ((mainnet, testnet)) {
    (Err(failure: KeystoreLockedFailure()), _) ||
    (
      _,
      Err(failure: KeystoreLockedFailure()),
    ) => const Err(LegacyImportDeferred()),
    (Ok(value: final main), Ok(value: final test)) => Ok((
      mainnet: main,
      testnet: test,
    )),
    _ => const Err(LegacyImportUnavailable()),
  };
}

final class _PreparedExchange implements PreparedOwner {
  static const _emptyRecords = (mainnet: null, testnet: null);
  final ExchangeStore _store;
  final ExchangeKeychain _legacy;

  const _PreparedExchange(this._store, this._legacy);

  ExchangeDatabase get _db => _store.database;

  @override
  Future<Result<void, LegacyImportFailure>> importLegacy(
    LegacySource source,
  ) async {
    switch (await receipt()) {
      case Ok(value: OwnerReadiness.imported):
        return const Ok(null);
      case Ok(value: OwnerReadiness.initialized):
        return const Err(LegacyImportVerificationFailed());
      case Err(:final failure):
        return Err(failure);
      case Ok(value: OwnerReadiness.pending):
        break;
    }
    final records = await _readRecords(_legacy);
    if (records case Err(:final failure)) return Err(failure);
    final keys = (records as Ok<_Records, LegacyImportFailure>).value;
    return importLegacyDatabase(
      id: exchangeImportReceipt,
      source: source.file,
      sourceSchemaVersion: source.schemaVersion,
      destination: _db,
      copyAndVerify: (legacy) async {
        if (!await _isEmpty()) return false;
        final rows = <_BasicAuth>[];
        for (final row in legacy.select('''
          SELECT id, exchange_testnet_basic_auth_username,
                 exchange_testnet_basic_auth_password
          FROM settings ORDER BY id
        ''')) {
          final [id, username, password] = row.values.toList();
          if (id is! int || username is! String? || password is! String?) {
            return false;
          }
          rows.add((id: id, username: username, password: password));
        }
        // Admission requires the Settings row the app always wrote.
        if (!rows.any((row) => row.id == 1)) return false;
        return _insertAndVerify(keys, rows);
      },
    );
  }

  @override
  Future<Result<void, LegacyImportFailure>> initializeFresh() async {
    switch (await receipt()) {
      case Ok(value: OwnerReadiness.initialized):
        return const Ok(null);
      case Ok(value: OwnerReadiness.imported):
        return const Err(LegacyImportVerificationFailed());
      case Err(:final failure):
        return Err(failure);
      case Ok(value: OwnerReadiness.pending):
        break;
    }
    // The keychain is not consulted: any record there is ignored residue.
    try {
      await _db.transaction(() async {
        if (!await _isEmpty() ||
            !await _insertAndVerify(_emptyRecords, const [
              (id: 1, username: null, password: null),
            ])) {
          throw const _VerificationRejected();
        }
        await _db.customStatement(
          'INSERT INTO legacy_import_receipts (id) VALUES (?)',
          [exchangeFreshReceipt],
        );
      });
      return const Ok(null);
    } on _VerificationRejected {
      return const Err(LegacyImportVerificationFailed());
    } on SqliteException {
      return const Err(LegacyImportUnavailable());
    }
  }

  Future<bool> _isEmpty() async =>
      (await _db
              .customSelect('SELECT 1 FROM exchange_api_credentials LIMIT 1')
              .getSingleOrNull()) ==
          null &&
      (await _db
              .customSelect('SELECT 1 FROM exchange_basic_auth LIMIT 1')
              .getSingleOrNull()) ==
          null;

  Future<bool> _insertAndVerify(_Records keys, List<_BasicAuth> rows) async {
    await _db.customStatement(
      '''
      INSERT INTO exchange_api_credentials (environment, encoded_record)
      VALUES ('mainnet', ?), ('testnet', ?)
      ''',
      [keys.mainnet, keys.testnet],
    );
    for (final row in rows) {
      await _db.customStatement(
        '''
        INSERT INTO exchange_basic_auth (settings_id, username, password)
        VALUES (?, ?, ?)
        ''',
        [row.id, row.username, row.password],
      );
    }
    if (await _readKeys() != keys) return false;
    final copied = await _db
        .customSelect(
          'SELECT settings_id, username, password '
          'FROM exchange_basic_auth ORDER BY settings_id',
        )
        .get();
    if (copied.length != rows.length) return false;
    for (var i = 0; i < rows.length; i++) {
      final row = copied[i];
      if (rows[i] !=
          (
            id: row.read<int>('settings_id'),
            username: row.readNullable<String>('username'),
            password: row.readNullable<String>('password'),
          )) {
        return false;
      }
    }
    return true;
  }

  Future<_Records?> _readKeys() => readExchangeApiRecords(_db);

  @override
  Future<Result<OwnerReadiness, LegacyImportFailure>> receipt() =>
      readExchangeReadiness(_db);

  @override
  Future<Result<void, LegacyImportFailure>> close() async {
    try {
      await _store.handle.close();
      return const Ok(null);
    } on Exception {
      return const Err(LegacyImportUnavailable());
    }
  }
}

final class _VerificationRejected implements Exception {
  const _VerificationRejected();
}
