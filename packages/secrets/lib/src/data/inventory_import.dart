import 'dart:io';

import 'package:drift/drift.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../crypto/access_verifier.dart';
import '../domain/domain.dart';
import 'inventory_store.dart';
import 'owner_keychain.dart';
import 'secrets_database.dart';
import 'secrets_database.drift.dart';

const defaultViewId = 'all';
const initialCredentialId = 'initial-credential';
const _imported = 'split-v1/secrets';
const _fresh = 'fresh-v1/secrets';

/// Foreground participant for the wallet inventory, the derivation registry and
/// the first access view. The receipt commits with all three projections.
final class SecretsImport implements LegacyImportParticipant {
  final File _file;

  SecretsImport({required this._file});

  @override
  String get ownerId => 'secrets';

  @override
  Future<bool> hasState() async => [
    '',
    '-wal',
    '-shm',
    '-journal',
    '.retire-pending',
  ].any((suffix) => File('${_file.path}$suffix').existsSync());

  @override
  Future<Result<PreparedOwner, LegacyImportFailure>> prepare(
    ExclusiveAdmission admission,
    OwnerOrigin origin,
  ) async => (await InventoryStore.open(
    _file,
    admission,
    existing: false,
  )).map(_PreparedInventory.new).mapErr(_mapOpenFailure);

  @override
  Future<Result<OwnerReadiness, LegacyImportFailure>> inspect(
    RuntimeAdmission admission,
  ) async {
    final opened = await InventoryStore.open(_file, admission, existing: true);
    switch (opened) {
      case Err(:final failure):
        return Err(_mapOpenFailure(failure));
      case Ok(:final value):
        try {
          return await readInventoryReadiness(value.database);
        } finally {
          await value.close();
        }
    }
  }

  static LegacyImportFailure _mapOpenFailure(DatabaseOpenFailure failure) =>
      switch (failure) {
        DatabaseNotReady() ||
        DatabaseKeyUnavailable(
          reason: DatabaseKeyProblem.locked,
        ) => const LegacyImportDeferred(),
        _ => const LegacyImportUnavailable(),
      };
}

Future<Result<OwnerReadiness, LegacyImportFailure>> readInventoryReadiness(
  SecretsDatabase database,
) async {
  try {
    final state = await database.select(database.accessState).getSingleOrNull();
    return switch (state?.importReceipt) {
      null => const Ok(OwnerReadiness.pending),
      _imported => const Ok(OwnerReadiness.imported),
      _fresh => const Ok(OwnerReadiness.initialized),
      _ => const Err(LegacyImportVerificationFailed()),
    };
  } on SqliteException {
    return const Err(LegacyImportUnavailable());
  }
}

final class _PreparedInventory implements PreparedOwner {
  final InventoryStore _store;

  _PreparedInventory(this._store);

  SecretsDatabase get _database => _store.database;

  @override
  Future<Result<void, LegacyImportFailure>> importLegacy(LegacySource source) =>
      _initialize(source);

  @override
  Future<Result<void, LegacyImportFailure>> initializeFresh() =>
      _initialize(null);

  Future<Result<void, LegacyImportFailure>> _initialize(
    LegacySource? source,
  ) async {
    final expected = source == null
        ? OwnerReadiness.initialized
        : OwnerReadiness.imported;
    try {
      return await _database.transaction(() async {
        final readiness = await receipt();
        switch (readiness) {
          case Err(:final failure):
            return Err(failure);
          case Ok(:final value) when value == expected:
            return const Ok(null);
          case Ok(value: OwnerReadiness.pending):
            break;
          case Ok():
            return const Err(LegacyImportVerificationFailed());
        }

        for (final table in _database.allTables) {
          final rows = await _database
              .customSelect('SELECT 1 FROM ${table.actualTableName} LIMIT 1')
              .get();
          if (rows.isNotEmpty) throw const _VerificationRejected();
        }

        // Even on a fresh SQLite install, an iOS keychain can outlive the app
        // container. Preserve any existing access protection.
        final access = await _readLegacyAccess();
        if (source != null) await _copyLegacy(source);

        final pin = access.pin;
        if (pin != null) {
          final salt = AccessVerifier.newSalt();
          final verifier = await AccessVerifier.derive(pin, salt);
          try {
            final written = await _database
                .into(_database.credentials)
                .insertReturning(
                  CredentialsCompanion.insert(
                    id: initialCredentialId,
                    scheme: AccessVerifier.scheme,
                    salt: salt,
                    params: AccessVerifier.params,
                    verifier: verifier,
                  ),
                );
            if (!AccessVerifier.supports(
                  storedScheme: written.scheme,
                  storedParams: written.params,
                  salt: written.salt,
                  verifier: written.verifier,
                ) ||
                !AccessVerifier.equals(verifier, written.verifier) ||
                !salt.indexed.every(
                  (entry) => written.salt[entry.$1] == entry.$2,
                )) {
              throw const _VerificationRejected();
            }
          } finally {
            verifier.fillRange(0, verifier.length, 0);
          }
        }
        await _database
            .into(_database.views)
            .insert(
              ViewsCompanion.insert(
                id: defaultViewId,
                name: 'All',
                credentialId: Value(pin != null ? initialCredentialId : null),
              ),
            );
        await _database.customStatement(
          '''
          INSERT INTO view_members (view_id, member)
          SELECT DISTINCT ?, CASE
            WHEN secret_fingerprint IS NULL THEN 'wallet:' || id
            ELSE 'secret:' || secret_fingerprint
          END
          FROM wallets
          UNION
          SELECT ?, 'secret:' || parent_fingerprint FROM derivations
        ''',
          [defaultViewId, defaultViewId],
        );
        await _database
            .into(_database.accessState)
            .insert(
              AccessStateCompanion.insert(
                singleton: const Value(1),
                failedAttempts: access.failedAttempts,
                lockedUntil: Value(access.lockedUntil),
                importReceipt: source == null ? _fresh : _imported,
              ),
            );
        return const Ok(null);
      });
    } on _VerificationRejected {
      return const Err(LegacyImportVerificationFailed());
    } on _WrongSchema {
      return const Err(LegacySourceSchemaMismatch());
    } on _LegacyAccessUnavailable catch (error) {
      return Err(error.failure);
    } on SqliteException {
      return const Err(LegacyImportUnavailable());
    } on FileSystemException {
      return const Err(LegacyImportUnavailable());
    }
  }

  Future<void> _copyLegacy(LegacySource source) async {
    if (source.schemaVersion != 16) throw const _WrongSchema();
    final legacy = sqlite3.open(source.file.path, mode: OpenMode.readOnly);
    try {
      legacy.execute('BEGIN');
      if (legacy.userVersion != source.schemaVersion) {
        throw const _WrongSchema();
      }
      // Keep original stored values, including unknown enum text and the
      // spelling of descriptors and timestamps. Never reconstruct a wallet.
      await _copy(
        legacy,
        destination: 'wallets',
        columns:
            'id,secret_fingerprint,master_fingerprint,signer,network,xpub,'
            'external_descriptor,internal_descriptor,label,birthday,is_default',
        query: '''
          SELECT id, CASE WHEN signer = 'local' THEN master_fingerprint END,
                 master_fingerprint, signer, network, xpub,
                 external_public_descriptor, internal_public_descriptor,
                 label, birthday, is_default
          FROM wallet_metadatas ORDER BY id
        ''',
        order: 'id',
      );
      await _copy(
        legacy,
        destination: 'derivations',
        columns: 'parent_fingerprint,path,application,status,alias',
        query: '''
          SELECT xprv_fingerprint, path, application, status, alias
          FROM bip85_derivations ORDER BY xprv_fingerprint, path
        ''',
        order: 'parent_fingerprint,path',
      );
    } finally {
      legacy.close();
    }
  }

  Future<void> _copy(
    Database legacy, {
    required String destination,
    required String columns,
    required String query,
    required String order,
  }) async {
    final rows = legacy.select(query);
    final placeholders = List.filled(rows.columnNames.length, '?').join(',');
    for (final row in rows) {
      await _database.customStatement(
        'INSERT INTO $destination ($columns) VALUES ($placeholders)',
        row.values.toList(),
      );
    }
    final copy = await _database
        .customSelect('SELECT $columns FROM $destination ORDER BY $order')
        .get();
    if (rows.length != copy.length) throw const _VerificationRejected();
    for (var index = 0; index < rows.length; index++) {
      final original = rows[index].values.iterator;
      final inserted = copy[index].data.values;
      for (final value in inserted) {
        if (!original.moveNext() || original.current != value) {
          throw const _VerificationRejected();
        }
      }
      if (original.moveNext()) throw const _VerificationRejected();
    }
  }

  Future<({String? pin, int failedAttempts, int? lockedUntil})>
  _readLegacyAccess() async {
    final keychain = OwnerKeychain();
    Future<String?> read(OwnerKey key) async => switch (await keychain.read(
      key,
    )) {
      Ok(:final value) => value,
      Err(failure: KeystoreLockedFailure()) =>
        throw const _LegacyAccessUnavailable(LegacyImportDeferred()),
      Err() => throw const _LegacyAccessUnavailable(LegacyImportUnavailable()),
    };
    final pin = await read(OwnerKey.pin);
    final rawAttempts = await read(OwnerKey.attempts);
    final rawLock = await read(OwnerKey.lockedUntil);
    final attempts = rawAttempts == null ? 0 : int.tryParse(rawAttempts);
    final lock = rawLock == null ? null : int.tryParse(rawLock);
    const maxEpoch = 8640000000000000;
    if (attempts == null ||
        attempts < 0 ||
        (rawLock != null &&
            (lock == null || lock < -maxEpoch || lock > maxEpoch))) {
      throw const _VerificationRejected();
    }
    return (pin: pin, failedAttempts: attempts, lockedUntil: lock);
  }

  @override
  Future<Result<OwnerReadiness, LegacyImportFailure>> receipt() =>
      readInventoryReadiness(_database);

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

final class _VerificationRejected implements Exception {
  const _VerificationRejected();
}

final class _WrongSchema implements Exception {
  const _WrongSchema();
}

final class _LegacyAccessUnavailable implements Exception {
  final LegacyImportFailure failure;

  const _LegacyAccessUnavailable(this.failure);
}
