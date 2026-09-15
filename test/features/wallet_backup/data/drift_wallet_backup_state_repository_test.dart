import 'dart:async';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/wallet_backup/data/drift_wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

final _checkpoint = WalletBackupRemoteCheckpoint(
  generation: 4,
  etag: 'a' * 64,
  ciphertextSha256: 'b' * 64,
);

void main() {
  late SqliteDatabase database;
  late DriftWalletBackupStateRepository repository;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    repository = DriftWalletBackupStateRepository(database);
  });

  tearDown(() => database.close());

  test(
    'Payjoin observations are durable and deduplicated by represented values',
    () async {
      final initial = WalletPayjoinSettings(
        enabled: false,
        minimumAmountSats: 10000,
        sessionLifetimeSeconds: 3600,
      );
      expect(
        (await repository.recordObservedPayjoinPolicy(initial) as Ok).value,
        1,
      );
      final reopened = DriftWalletBackupStateRepository(database);
      expect(
        (await reopened.recordObservedPayjoinPolicy(
                  WalletPayjoinSettings(
                    enabled: false,
                    minimumAmountSats: 10000,
                    sessionLifetimeSeconds: 3600,
                  ),
                )
                as Ok)
            .value,
        1,
      );
      expect(
        (await reopened.recordObservedPayjoinPolicy(
                  WalletPayjoinSettings(
                    enabled: true,
                    minimumAmountSats: 10000,
                    sessionLifetimeSeconds: 3600,
                  ),
                )
                as Ok)
            .value,
        2,
      );
      expect(
        (await reopened.recordObservedPayjoinPolicy(
                  WalletPayjoinSettings(
                    enabled: true,
                    minimumAmountSats: 20000,
                    sessionLifetimeSeconds: 3600,
                  ),
                )
                as Ok)
            .value,
        3,
      );
      expect(
        (await reopened.recordObservedPayjoinPolicy(
                  WalletPayjoinSettings(
                    enabled: true,
                    minimumAmountSats: 20000,
                    sessionLifetimeSeconds: 7200,
                  ),
                )
                as Ok)
            .value,
        4,
      );
    },
  );

  test(
    'failed Payjoin revision recording also rolls back its observed value',
    () async {
      final initial = WalletPayjoinSettings(
        enabled: false,
        minimumAmountSats: 10000,
        sessionLifetimeSeconds: 3600,
      );
      expect(await repository.recordObservedPayjoinPolicy(initial), isA<Ok>());
      final before = await database
          .select(database.walletBackupStates)
          .getSingle();
      await database.customStatement('''
      CREATE TRIGGER reject_payjoin_backup_revision
      BEFORE UPDATE OF local_revision ON wallet_backup_states
      BEGIN SELECT RAISE(ABORT, 'injected revision failure'); END
    ''');
      expect(
        await repository.recordObservedPayjoinPolicy(
          WalletPayjoinSettings(
            enabled: true,
            minimumAmountSats: 10000,
            sessionLifetimeSeconds: 3600,
          ),
        ),
        isA<Err>(),
      );
      expect(
        await database.select(database.walletBackupStates).getSingle(),
        before,
      );
    },
  );

  test('an idle backup state subscription can be cancelled', () async {
    final first = Completer<void>();
    final subscription = repository.watch().listen((state) {
      expect(state, isA<Ok>());
      if (!first.isCompleted) first.complete();
    });
    await first.future;
    await pumpEventQueue();
    await subscription.cancel().timeout(const Duration(seconds: 5));
  });

  test(
    'changing server clears its checkpoint and marks backup dirty',
    () async {
      expect(
        await repository.setServerUrl('https://backup.example.com'),
        isA<Ok>(),
      );

      final state = (await repository.get() as Ok).value;
      expect(state.customServerUrl, 'https://backup.example.com');
      expect(state.dirty, isTrue);
      expect(state.localRevision, 1);
    },
  );

  test('writing the same server is idempotent', () async {
    expect(
      await repository.setServerUrl('https://backup.example.com'),
      isA<Ok>(),
    );
    expect(
      await repository.setServerUrl('https://backup.example.com'),
      isA<Ok>(),
    );

    final state = (await repository.get() as Ok).value;
    expect(state.localRevision, 1);
  });

  test('the recovery fence is one durable value', () async {
    expect(
      await repository.setRecoveryState(
        WalletBackupRecoveryState.needsAttention,
      ),
      isA<Ok>(),
    );

    final state = (await repository.get() as Ok).value;
    expect(state.recoveryState, WalletBackupRecoveryState.needsAttention);
    expect(state.needsAttention, isTrue);
    expect(state.recoveryBlocked, isTrue);
    expect(state.canPublish, isFalse);
  });

  test('publishing the current revision leaves nothing dirty', () async {
    expect(await repository.recordLocalMutation(), isA<Ok>());

    expect(
      await repository.recordPublication(
        publishedRevision: 1,
        succeededAt: 10,
        checkpoint: _checkpoint,
      ),
      isA<Ok>(),
    );

    final state = (await repository.get() as Ok).value;
    expect(state.localRevision, 1);
    expect(state.uploadedRevision, 1);
    expect(state.dirty, isFalse);
  });

  test('a mutation during a store leaves the backup dirty', () async {
    expect(await repository.recordLocalMutation(), isA<Ok>());
    // The publication captured revision 1; this one lands while it is in
    // flight.
    expect(await repository.recordLocalMutation(), isA<Ok>());

    expect(
      await repository.recordPublication(
        publishedRevision: 1,
        succeededAt: 10,
        checkpoint: _checkpoint,
      ),
      isA<Ok>(),
    );

    final state = (await repository.get() as Ok).value;
    expect(state.localRevision, 2);
    expect(state.uploadedRevision, 1);
    expect(state.dirty, isTrue);
  });

  test('an older store never walks the acknowledged revision back', () async {
    expect(await repository.recordLocalMutation(), isA<Ok>());
    expect(await repository.recordLocalMutation(), isA<Ok>());
    expect(
      await repository.recordPublication(
        publishedRevision: 2,
        succeededAt: 10,
        checkpoint: _checkpoint,
      ),
      isA<Ok>(),
    );

    expect(
      await repository.recordPublication(
        publishedRevision: 1,
        succeededAt: 11,
        checkpoint: _checkpoint,
      ),
      isA<Ok>(),
    );

    final state = (await repository.get() as Ok).value;
    expect(state.uploadedRevision, 2);
    expect(state.dirty, isFalse);
  });

  test('clearing a remote checkpoint lowers the recovery fence', () async {
    expect(
      await repository.setRecoveryState(
        WalletBackupRecoveryState.needsAttention,
      ),
      isA<Ok>(),
    );
    expect(await repository.saveRemoteCheckpoint(_checkpoint), isA<Ok>());
    expect(await repository.clearRemoteCheckpoint(), isA<Ok>());

    final state = (await repository.get() as Ok).value;
    expect(state.recoveryState, WalletBackupRecoveryState.idle);
    expect(state.recoveryBlocked, isFalse);
    expect(state.remoteCheckpoint, isNull);
  });

  test('a successful publication stores the acknowledged head', () async {
    expect(await repository.recordLocalMutation(), isA<Ok>());
    expect(
      await repository.recordPublication(
        publishedRevision: 1,
        succeededAt: 10,
        checkpoint: _checkpoint,
      ),
      isA<Ok>(),
    );

    final checkpoint = (await repository.get() as Ok).value.remoteCheckpoint;
    expect(checkpoint?.generation, 4);
    expect(checkpoint?.etag, 'a' * 64);
    expect(checkpoint?.ciphertextSha256, 'b' * 64);
  });

  test('a tombstone checkpoint survives without a ciphertext hash', () async {
    expect(
      await repository.saveRemoteCheckpoint(
        WalletBackupRemoteCheckpoint(
          generation: 7,
          etag: 'c' * 64,
          ciphertextSha256: null,
        ),
      ),
      isA<Ok>(),
    );

    final checkpoint = (await repository.get() as Ok).value.remoteCheckpoint;
    expect(checkpoint?.generation, 7);
    expect(checkpoint?.found, isFalse);
  });

  test('changing the server drops the checkpoint it belonged to', () async {
    expect(await repository.saveRemoteCheckpoint(_checkpoint), isA<Ok>());

    expect(
      await repository.setServerUrl('https://backup.example.com'),
      isA<Ok>(),
    );

    expect((await repository.get() as Ok).value.remoteCheckpoint, isNull);
  });
}
