import 'package:bb_mobile/core/storage/backup_revision_recorder.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/keychain_manifest/data/keychain_manifest_repository_impl.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_requests.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'support/manifest_fixtures.dart';

/// The manifest raises Bull backup's dirty signal inside the transaction that
/// earns it (decision 7).
///
/// Forget correctness depends on this: if a crash between the delete and the
/// signal could lose the signal, the forgotten wallet would still be in the
/// next published snapshot. These tests read the revision straight out of the
/// database rather than through the backup feature, because what is being
/// asserted is that the manifest wrote it, not that something else noticed.
void main() {
  late SqliteDatabase database;
  late KeychainManifestRepositoryImpl repository;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    repository = KeychainManifestRepositoryImpl(
      database,
      backupRevisions: DriftBackupRevisionRecorder(database),
    );
  });

  tearDown(() async {
    await repository.close();
    await database.close();
  });

  Future<int> localRevision() async =>
      (await database.select(database.walletBackupStates).getSingleOrNull())
          ?.localRevision ??
      0;

  test('forgetting a wallet records a revision', () async {
    expect(
      await repository.upsertPassphraseWallet(passphraseWalletEntry()),
      isA<Ok<void, KeychainManifestFailure>>(),
    );
    final afterSave = await localRevision();
    expect(afterSave, greaterThan(0));

    expect(
      await repository.removePassphraseWallet(
        parentFingerprint: manifestFingerprint,
        walletId: 'passphrase-1',
      ),
      isA<Ok<void, KeychainManifestFailure>>(),
    );

    expect(await localRevision(), greaterThan(afterSave));
  });

  test('a write that changes nothing records nothing', () async {
    expect(
      await repository.upsertPassphraseWallet(passphraseWalletEntry()),
      isA<Ok<void, KeychainManifestFailure>>(),
    );
    final afterSave = await localRevision();

    expect(
      await repository.upsertPassphraseWallet(passphraseWalletEntry()),
      isA<Ok<void, KeychainManifestFailure>>(),
    );

    expect(await localRevision(), afterSave);
  });

  test('a recovery-originated write records nothing', () async {
    expect(
      await repository.restoreSnapshot(
        manifest(entries: [passphraseWalletEntry()]),
      ),
      isA<Ok<KeychainManifestRestoreReport, KeychainManifestFailure>>(),
    );

    expect(
      await localRevision(),
      0,
      reason: 'restoring a snapshot must not publish it straight back',
    );
  });

  test('a recovery-originated edit records nothing', () async {
    await repository.upsertPassphraseWallet(
      passphraseWalletEntry(hint: 'Old hint'),
    );
    final afterSave = await localRevision();

    await repository.restoreSnapshot(
      manifest(
        entries: [passphraseWalletEntry(hint: 'New hint', updatedAt: 7)],
      ),
    );

    expect(await localRevision(), afterSave);
  });

  test('a failed delete leaves the revision alone', () async {
    expect(
      await repository.upsertPassphraseWallet(passphraseWalletEntry()),
      isA<Ok<void, KeychainManifestFailure>>(),
    );
    final afterSave = await localRevision();

    expect(
      await repository.removePassphraseWallet(
        parentFingerprint: manifestFingerprint,
        walletId: 'never-existed',
      ),
      isA<Err<void, KeychainManifestFailure>>(),
    );

    expect(await localRevision(), afterSave);
  });

  test('a rejected edit leaves the revision alone', () async {
    await repository.upsertPassphraseWallet(
      passphraseWalletEntry(hint: 'Old hint'),
    );
    final afterSave = await localRevision();

    expect(
      await repository.updatePassphraseLabelHint(
        parentFingerprint: manifestFingerprint,
        walletId: 'passphrase-1',
        hint: const KeychainManifestEdit('Rival hint'),
        updatedAt: 2,
      ),
      isA<Err<void, KeychainManifestFailure>>(),
    );

    expect(await localRevision(), afterSave);
  });
}
