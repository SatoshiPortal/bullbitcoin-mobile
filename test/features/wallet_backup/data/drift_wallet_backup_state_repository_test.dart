import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/data/drift_wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late File file;
  late SqliteDatabase database;
  late DriftWalletBackupStateRepository repository;
  final identity = 'a' * 64;
  final secondIdentity = 'b' * 64;
  final checkpoint = WalletBackupCheckpoint(
    generation: 1,
    etag: '1' * 64,
    ciphertextHash: '2' * 64,
  );
  final time = DateTime.utc(2026, 9, 18);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'bull-backup-state-test-',
    );
    file = File('${directory.path}/backup.sqlite');
    database = SqliteDatabase(NativeDatabase(file));
    repository = DriftWalletBackupStateRepository(database);
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  Future<void> reopen() async {
    await database.close();
    database = SqliteDatabase(NativeDatabase(file));
    repository = DriftWalletBackupStateRepository(database);
  }

  Future<WalletBackupState> state([String? key]) async =>
      (await repository.get(key ?? identity)
              as Ok<WalletBackupState, WalletBackupFailure>)
          .value;

  Future<Result<void, WalletBackupFailure>> publish({
    String? expectedEtag,
    WalletBackupCheckpoint? next,
  }) => repository.recordPublication(
    identity: identity,
    expectedEtag: expectedEtag,
    checkpoint: next ?? checkpoint,
    contentHash: '3' * 64,
    succeededAt: time,
  );

  test(
    'the pending wizard choice initializes once and never overwrites a later explicit choice',
    () async {
      expect(
        await repository.setEnabled(true, onlyIfUndecided: true),
        isA<Ok>(),
      );
      await reopen();
      expect(
        await repository.setEnabled(false, onlyIfUndecided: true),
        isA<Ok>(),
      );
      expect((await state()).enabled, isTrue);
      expect(await repository.setEnabled(false), isA<Ok>());
      await reopen();
      expect(
        await repository.setEnabled(true, onlyIfUndecided: true),
        isA<Ok>(),
      );
      expect((await state()).enabled, isFalse);
    },
  );

  test(
    'consent, off, checkpoint and acknowledged content survive database reopen',
    () async {
      final initial =
          (await repository.getControl()
                  as Ok<WalletBackupControl, WalletBackupFailure>)
              .value;
      expect(initial.enabled, isNull);
      expect(await repository.setEnabled(true), isA<Ok>());
      expect(await publish(), isA<Ok>());
      await reopen();
      expect((await state()).enabled, isTrue);
      expect((await state()).checkpoint!.etag, checkpoint.etag);
      expect((await state()).confirmedContentHash, '3' * 64);
      expect((await state()).lastSuccessAt, time);
      expect((await state(secondIdentity)).checkpoint, isNull);
      expect(await repository.setEnabled(false), isA<Ok>());
      await reopen();
      expect((await state()).enabled, isFalse);
      expect((await state()).checkpoint!.etag, checkpoint.etag);
    },
  );

  test(
    'the global recovery fence survives restart and blocks every identity',
    () async {
      expect(await repository.setEnabled(true), isA<Ok>());
      expect(await repository.setRecoveryIncomplete(true), isA<Ok>());
      await reopen();
      for (final key in [identity, secondIdentity]) {
        expect((await state(key)).canPublish, isFalse);
        expect((await state(key)).recoveryIncomplete, isTrue);
      }
      expect(await publish(), isA<Err<void, WalletBackupFailure>>());
      expect((await state()).checkpoint, isNull);
      expect(await repository.setEnabled(false), isA<Ok>());
      expect((await state()).recoveryIncomplete, isTrue);
      expect(await repository.setRecoveryIncomplete(false), isA<Ok>());
      expect((await state()).enabled, isFalse);
    },
  );

  test(
    'stale publication replies cannot regress the acknowledged checkpoint',
    () async {
      expect(await publish(), isA<Ok>());
      final next = WalletBackupCheckpoint(
        generation: 2,
        etag: '4' * 64,
        ciphertextHash: '5' * 64,
      );
      expect(
        await publish(expectedEtag: checkpoint.etag, next: next),
        isA<Ok>(),
      );
      expect(await publish(), isA<Err>());
      expect((await state()).checkpoint!.etag, next.etag);
    },
  );

  test(
    'a failed acknowledgement leaves all publication fields unchanged',
    () async {
      expect(await publish(), isA<Ok>());
      await database.customStatement('''
      CREATE TRIGGER reject_backup_ack BEFORE UPDATE OF confirmed_content_hash
      ON wallet_backup_states BEGIN SELECT RAISE(ABORT, 'injected failure'); END
    ''');
      final next = WalletBackupCheckpoint(
        generation: 2,
        etag: '4' * 64,
        ciphertextHash: '5' * 64,
      );
      expect(
        await publish(expectedEtag: checkpoint.etag, next: next),
        isA<Err>(),
      );
      await reopen();
      expect((await state()).checkpoint!.etag, checkpoint.etag);
      expect((await state()).checkpoint!.generation, 1);
      expect((await state()).lastSuccessAt, time);
    },
  );

  test(
    'remote deletion requires off and the matching acknowledged version',
    () async {
      expect(await publish(), isA<Ok>());
      expect(await repository.setEnabled(true), isA<Ok>());
      expect(
        await repository.clearRemoteCheckpoint(
          identity: identity,
          expectedEtag: checkpoint.etag,
        ),
        isA<Err>(),
      );
      expect(await repository.setEnabled(false), isA<Ok>());
      expect(
        await repository.clearRemoteCheckpoint(
          identity: identity,
          expectedEtag: '0' * 64,
        ),
        isA<Err>(),
      );
      expect(
        await repository.clearRemoteCheckpoint(
          identity: identity,
          expectedEtag: checkpoint.etag,
        ),
        isA<Ok>(),
      );
      await reopen();
      expect((await state()).checkpoint, isNull);
      expect((await state()).confirmedContentHash, isNull);
      expect((await state()).lastSuccessAt, isNull);
      expect((await state()).enabled, isFalse);
    },
  );
}
