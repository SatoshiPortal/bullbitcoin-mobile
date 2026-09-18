import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/nostr_key_repository.dart';
import 'package:drift/drift.dart';

final class NostrKeyRepositoryImpl implements NostrKeyRepository {
  final SqliteDatabase _database;

  const NostrKeyRepositoryImpl(this._database);

  @override
  Stream<void> get changes => _database
      .tableUpdates(TableUpdateQuery.onTable(_database.keychainNostrKeys))
      .map((_) {});

  @override
  Future<Result<List<NostrKeyRecord>, KeychainManifestFailure>> getAll() =>
      _transaction(() async {
        final rows =
            await (_database.select(_database.keychainNostrKeys)..orderBy([
                  (row) => OrderingTerm.asc(row.parentFingerprint),
                  (row) => OrderingTerm.asc(row.identity),
                ]))
                .get();
        return Ok([
          for (final row in rows)
            NostrKeyRecord(
              parentFingerprint: row.parentFingerprint,
              identity: row.identity,
              publicKey: row.publicKey,
              purpose: row.purpose,
              description: row.description,
              createdAt: row.createdAt.toUtc(),
              updatedAt: row.updatedAt.toUtc(),
            ),
        ]);
      });

  @override
  Future<Result<void, KeychainManifestFailure>> insert(NostrKeyRecord record) =>
      _transaction(() async {
        await _database
            .into(_database.keychainNostrKeys)
            .insert(_model(record));
        return const Ok(null);
      });

  @override
  Future<Result<void, KeychainManifestFailure>> restore(
    NostrKeyRecord record,
  ) => _transaction(() async {
    final existing =
        await (_database.select(_database.keychainNostrKeys)
              ..where((row) => row.publicKey.equals(record.publicKey)))
            .getSingleOrNull();
    if (existing == null) {
      await _database.into(_database.keychainNostrKeys).insert(_model(record));
    } else if (existing.parentFingerprint != record.parentFingerprint ||
        existing.identity != record.identity) {
      return const Err(KeychainManifestInvalidKeyFailure());
    }
    return const Ok(null);
  });

  @override
  Future<Result<void, KeychainManifestFailure>> update(
    NostrKeyRecord record, {
    required DateTime expectedUpdatedAt,
  }) => _transaction(() async {
    final changed =
        await (_database.update(_database.keychainNostrKeys)..where(
              (row) =>
                  row.publicKey.equals(record.publicKey) &
                  row.parentFingerprint.equals(record.parentFingerprint) &
                  row.identity.equals(record.identity) &
                  row.updatedAt.equals(expectedUpdatedAt.toUtc()),
            ))
            .write(
              KeychainNostrKeysCompanion(
                purpose: Value(record.purpose),
                description: Value(record.description),
                updatedAt: Value(record.updatedAt.toUtc()),
              ),
            );
    return changed == 1
        ? const Ok(null)
        : const Err(KeychainManifestChangedFailure());
  });

  KeychainNostrKeysCompanion _model(NostrKeyRecord record) =>
      KeychainNostrKeysCompanion.insert(
        publicKey: record.publicKey,
        parentFingerprint: record.parentFingerprint,
        identity: record.identity,
        purpose: record.purpose,
        description: record.description,
        createdAt: record.createdAt.toUtc(),
        updatedAt: record.updatedAt.toUtc(),
      );

  Future<Result<T, KeychainManifestFailure>> _transaction<T>(
    Future<Result<T, KeychainManifestFailure>> Function() action,
  ) async {
    try {
      return await _database.transaction(action);
    } on Exception {
      return const Err(KeychainManifestStorageFailure());
    }
  }
}
