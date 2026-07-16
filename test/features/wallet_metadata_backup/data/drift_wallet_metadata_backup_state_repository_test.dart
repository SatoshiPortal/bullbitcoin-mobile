import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/drift_wallet_metadata_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_backup_state.dart';
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
}
