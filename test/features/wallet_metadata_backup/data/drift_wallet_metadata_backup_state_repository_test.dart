import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/drift_wallet_metadata_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_backup_state.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SqliteDatabase database;
  late DriftWalletMetadataBackupStateRepository repository;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    repository = DriftWalletMetadataBackupStateRepository(database);
  });
  tearDown(() => database.close());

  test('persists Bullnym checkpoint and durable dirty revision', () async {
    const etag =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const hash =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final updated = await repository.update(
      (state) => state
          .withEnabled(true)
          .recordVerifiedHead(
            head: WalletMetadataBackupVerifiedHead(
              remoteGeneration: 3,
              remoteEtag: etag,
              snapshotRevision: 7,
              canonicalContentHash: hash,
              verifiedAt: 42,
            ),
            expectedDirtyRevision: 1,
          )
          .markDirty(),
    );
    expect(updated, isA<Ok>());

    final result = await repository.fetch();
    final state = switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw TestFailure('$failure'),
    };
    expect(state.dirty, isTrue);
    expect(state.dirtyRevision, 2);
    expect(state.lastSucceededAt, 42);
    expect(state.verifiedHead?.remoteGeneration, 3);
    expect(state.verifiedHead?.remoteEtag, etag);
  });

  test(
    'serializes concurrent functional updates against the latest row',
    () async {
      final updates = List.generate(
        12,
        (_) => repository.update((state) => state.markDirty()),
      );

      final results = await Future.wait(updates);

      expect(results, everyElement(isA<Ok>()));
      final state = _ok(await repository.fetch());
      expect(state.dirty, isTrue);
      expect(state.dirtyRevision, 12);
    },
  );

  test('fetch waits for queued writes before reading state', () async {
    final write = repository.update((state) => state.markDirty());
    final read = repository.fetch();

    expect(_ok(await write).dirtyRevision, 1);
    final state = _ok(await read);

    expect(state.dirty, isTrue);
    expect(state.dirtyRevision, 1);
  });

  test('repairs only clean apply-in-progress crash residue', () async {
    await _insertRecoveryRow(
      database,
      dirty: false,
      reason: WalletMetadataRecoveryBlockReason.applyInProgress,
    );

    final state = _ok(await repository.fetch());

    expect(state.dirty, isFalse);
    expect(state.recoveryBlock, isNull);

    final persisted = _ok(await repository.fetch());
    expect(persisted.recoveryBlock, isNull);
  });

  test(
    'functional updates repair clean apply-in-progress residue first',
    () async {
      await _insertRecoveryRow(
        database,
        dirty: false,
        reason: WalletMetadataRecoveryBlockReason.applyInProgress,
      );

      final updated = _ok(
        await repository.update((state) => state.markDirty()),
      );

      expect(updated.dirty, isTrue);
      expect(updated.dirtyRevision, 1);
      expect(updated.recoveryBlock, isNull);
    },
  );

  test('keeps real interrupted apply blocked for retry or recovery', () async {
    await _insertRecoveryRow(
      database,
      dirty: true,
      reason: WalletMetadataRecoveryBlockReason.applyInProgress,
    );

    final state = _ok(await repository.fetch());

    expect(state.dirty, isTrue);
    expect(
      state.recoveryBlock?.reason,
      WalletMetadataRecoveryBlockReason.applyInProgress,
    );
  });

  test('returns storage failure for malformed recovery block rows', () async {
    await database.customStatement('''
      INSERT INTO wallet_metadata_backup_states (
        id,
        dirty,
        dirty_revision,
        recovery_blocked_reason
      ) VALUES (1, 0, 0, 'applyInProgress')
    ''');

    final result = await repository.fetch();

    expect(result, isA<Err>());
    expect((result as Err).failure, isA<WalletMetadataBackupStorageFailure>());
  });
}

WalletMetadataBackupState _ok(
  Result<WalletMetadataBackupState, WalletMetadataBackupFailure> result,
) {
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw TestFailure('$failure'),
  };
}

Future<void> _insertRecoveryRow(
  SqliteDatabase database, {
  required bool dirty,
  required WalletMetadataRecoveryBlockReason reason,
}) {
  return database.customStatement('''
    INSERT INTO wallet_metadata_backup_states (
      id,
      dirty,
      dirty_revision,
      recovery_blocked_reason,
      recovery_blocked_remote_generation,
      recovery_blocked_remote_etag,
      recovery_blocked_snapshot_revision,
      recovery_blocked_observed_at
    ) VALUES (
      1,
      ${dirty ? 1 : 0},
      ${dirty ? 1 : 0},
      '${reason.name}',
      2,
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      3,
      4
    )
  ''');
}
