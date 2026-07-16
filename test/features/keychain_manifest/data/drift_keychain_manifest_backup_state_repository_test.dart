import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/keychain_manifest/data/drift_keychain_manifest_backup_state_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_remote_backup.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SqliteDatabase database;
  late DriftKeychainManifestBackupStateRepository repository;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    repository = DriftKeychainManifestBackupStateRepository(database);
  });

  tearDown(() => database.close());

  test('preserves newer dirty work when an older upload succeeds', () async {
    await repository.setEnabled(true);
    await database
        .update(database.keychainManifestBackupStates)
        .write(
          const KeychainManifestBackupStatesCompanion(
            dirty: Value(true),
            dirtyRevision: Value(2),
          ),
        );

    await repository.recordSuccess(
      capturedDirtyRevision: 1,
      succeededAt: 20,
      checkpoint: const KeychainManifestRemoteCheckpoint(
        generation: 3,
        etag: 'etag',
      ),
      contentHash: 'hash',
    );

    final state = await repository.get();
    expect(state.enabled, isTrue);
    expect(state.dirty, isTrue);
    expect(state.dirtyRevision, 2);
    expect(state.remoteGeneration, 3);
    expect(state.remoteEtag, 'etag');
    expect(state.contentHash, 'hash');
    expect(state.lastSucceededAt, 20);
  });

  test(
    'first activation makes existing inventory durable dirty work',
    () async {
      await repository.setEnabled(true);
      final activated = await repository.get();

      expect(activated.enabled, isTrue);
      expect(activated.dirty, isTrue);
      expect(activated.dirtyRevision, 1);

      await repository.setEnabled(true);
      expect((await repository.get()).dirtyRevision, 1);

      await repository.setEnabled(false);
      final disabled = await repository.get();
      expect(disabled.enabled, isFalse);
      expect(disabled.dirty, isTrue);
      expect(disabled.dirtyRevision, 1);
    },
  );

  test('confirmed deletion clears remote status and version block', () async {
    await repository.recordSuccess(
      capturedDirtyRevision: 0,
      succeededAt: 20,
      checkpoint: const KeychainManifestRemoteCheckpoint(
        generation: 1,
        etag: 'etag',
      ),
      contentHash: 'hash',
    );
    await repository.blockUnsupportedVersion(2);
    await repository.clearRemoteCheckpoint();

    final state = await repository.get();
    expect(state.lastSucceededAt, isNull);
    expect(state.remoteGeneration, 0);
    expect(state.remoteEtag, isNull);
    expect(state.contentHash, isNull);
    expect(state.unsupportedVersion, isNull);
  });
}
