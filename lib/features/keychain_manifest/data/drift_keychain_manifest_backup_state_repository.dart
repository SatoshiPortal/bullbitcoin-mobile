import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_backup_state.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_remote_backup.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_backup_state_repository.dart';
import 'package:drift/drift.dart';

final class DriftKeychainManifestBackupStateRepository
    implements KeychainManifestBackupStateRepository {
  static const _id = 1;
  final SqliteDatabase database;

  const DriftKeychainManifestBackupStateRepository(this.database);

  Future<void> _ensureRow() async {
    await database
        .into(database.keychainManifestBackupStates)
        .insert(
          KeychainManifestBackupStatesCompanion.insert(id: const Value(_id)),
          mode: InsertMode.insertOrIgnore,
        );
  }

  @override
  Future<KeychainManifestBackupState> get() async {
    await _ensureRow();
    final row = await (database.select(
      database.keychainManifestBackupStates,
    )..where((table) => table.id.equals(_id))).getSingle();
    return _map(row);
  }

  @override
  Stream<KeychainManifestBackupState> watch() async* {
    await _ensureRow();
    yield* (database.select(
      database.keychainManifestBackupStates,
    )..where((table) => table.id.equals(_id))).watchSingle().map(_map);
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    await _ensureRow();
    await database.transaction(() async {
      final table = database.keychainManifestBackupStates;
      final current = await (database.select(
        table,
      )..where((row) => row.id.equals(_id))).getSingle();
      if (!enabled || current.enabled) {
        await (database.update(
          table,
        )..where((row) => row.id.equals(_id))).write(
          KeychainManifestBackupStatesCompanion(enabled: Value(enabled)),
        );
        return;
      }
      await (database.update(table)..where((row) => row.id.equals(_id))).write(
        KeychainManifestBackupStatesCompanion(
          enabled: const Value(true),
          dirty: const Value(true),
          dirtyRevision: Value(current.dirtyRevision + 1),
        ),
      );
    });
  }

  @override
  Future<void> recordAttempt(int attemptedAt) async {
    await _ensureRow();
    await (database.update(
      database.keychainManifestBackupStates,
    )..where((table) => table.id.equals(_id))).write(
      KeychainManifestBackupStatesCompanion(
        lastAttemptedAt: Value(attemptedAt),
      ),
    );
  }

  @override
  Future<void> recordSuccess({
    required int capturedDirtyRevision,
    required int succeededAt,
    required KeychainManifestRemoteCheckpoint checkpoint,
    required String contentHash,
  }) async {
    await _ensureRow();
    await database.transaction(() async {
      final table = database.keychainManifestBackupStates;
      await (database.update(table)..where((row) => row.id.equals(_id))).write(
        KeychainManifestBackupStatesCompanion(
          lastSucceededAt: Value(succeededAt),
          remoteGeneration: Value(checkpoint.generation),
          remoteEtag: Value(checkpoint.etag),
          contentHash: Value(contentHash),
          unsupportedVersion: const Value(null),
        ),
      );
      await (database.update(table)..where(
            (row) =>
                row.id.equals(_id) &
                row.dirtyRevision.equals(capturedDirtyRevision),
          ))
          .write(
            KeychainManifestBackupStatesCompanion(dirty: const Value(false)),
          );
    });
  }

  @override
  Future<void> blockUnsupportedVersion(int version) async {
    await _ensureRow();
    await (database.update(
      database.keychainManifestBackupStates,
    )..where((table) => table.id.equals(_id))).write(
      KeychainManifestBackupStatesCompanion(unsupportedVersion: Value(version)),
    );
  }

  @override
  Future<void> clearRemoteCheckpoint() async {
    await _ensureRow();
    await (database.update(
      database.keychainManifestBackupStates,
    )..where((table) => table.id.equals(_id))).write(
      const KeychainManifestBackupStatesCompanion(
        lastSucceededAt: Value(null),
        remoteGeneration: Value(0),
        remoteEtag: Value(null),
        contentHash: Value(null),
        unsupportedVersion: Value(null),
      ),
    );
  }

  KeychainManifestBackupState _map(KeychainManifestBackupStateRow row) =>
      KeychainManifestBackupState(
        enabled: row.enabled,
        dirty: row.dirty,
        dirtyRevision: row.dirtyRevision,
        lastAttemptedAt: row.lastAttemptedAt,
        lastSucceededAt: row.lastSucceededAt,
        remoteGeneration: row.remoteGeneration,
        remoteEtag: row.remoteEtag,
        contentHash: row.contentHash,
        unsupportedVersion: row.unsupportedVersion,
      );
}
