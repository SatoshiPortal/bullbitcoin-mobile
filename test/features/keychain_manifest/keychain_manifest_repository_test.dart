import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/keychain_manifest/data/keychain_manifest_repository_impl.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_requests.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'support/manifest_fixtures.dart';

/// Every manifest write is one named intent (spec F11).
///
/// What is asserted here is that each intent answers a collision the way its
/// own caller needs: a local edit, a re-derivation, and a recovery apply are
/// not the same question, and the generic save they used to share could only
/// give one answer to all three.
void main() {
  late SqliteDatabase database;
  late KeychainManifestRepositoryImpl repository;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    repository = KeychainManifestRepositoryImpl(database);
  });

  tearDown(() async {
    await repository.close();
    await database.close();
  });

  Future<List<KeychainManifestEntry>> stored() async =>
      (await repository.fetch(manifestFingerprint)
              as Ok<List<KeychainManifestEntry>, KeychainManifestFailure>)
          .value;

  Future<KeychainManifestEntry> single() async => (await stored()).single;

  group('upsertPassphraseWallet', () {
    test('inserts a record that is not there yet', () async {
      expect(
        await repository.upsertPassphraseWallet(
          passphraseWalletEntry(hint: 'Blue notebook'),
        ),
        isA<Ok<void, KeychainManifestFailure>>(),
      );

      final entry = await single();
      final wallet = entry.materializations.single as KeychainManifestWallet;
      expect(
        (wallet.walletId, wallet.descriptor, wallet.label, entry.description),
        (
          'passphrase-1',
          'wpkh(xpubPassphraseOne/<0;1>/*)',
          'Vault',
          'Blue notebook',
        ),
      );
    });

    test('writing the same record back changes nothing', () async {
      await repository.upsertPassphraseWallet(passphraseWalletEntry());

      expect(
        await repository.upsertPassphraseWallet(passphraseWalletEntry()),
        isA<Ok<void, KeychainManifestFailure>>(),
      );

      final entry = await single();
      expect(entry.updatedAt, 2);
      expect(await stored(), hasLength(1));
    });

    test('updates the label and hint of the same descriptor', () async {
      await repository.upsertPassphraseWallet(
        passphraseWalletEntry(hint: 'Old hint'),
      );

      expect(
        await repository.upsertPassphraseWallet(
          passphraseWalletEntry(label: 'Renamed', hint: 'New hint'),
        ),
        isA<Ok<void, KeychainManifestFailure>>(),
      );

      final entry = await single();
      final wallet = entry.materializations.single as KeychainManifestWallet;
      expect((wallet.label, entry.description), ('Renamed', 'New hint'));
      expect(
        entry.updatedAt,
        greaterThan(2),
        reason: 'an edit must be ordered after what it replaces',
      );
    });

    test(
      'refuses a second descriptor under a colliding seed fingerprint',
      () async {
        await repository.upsertPassphraseWallet(passphraseWalletEntry());

        // Same four-byte child fingerprint and path, so the same entry id, but
        // a different passphrase produced it. The fingerprint is a lookup hint,
        // never an identity (spec 6.5).
        expect(
          await repository.upsertPassphraseWallet(
            passphraseWalletEntry(
              walletId: 'passphrase-2',
              descriptor: 'wpkh(xpubPassphraseTwo/<0;1>/*)',
              label: 'Other',
            ),
          ),
          isA<Err<void, KeychainManifestFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<KeychainManifestConflictFailure>(),
          ),
        );

        final wallet =
            (await single()).materializations.single as KeychainManifestWallet;
        expect(
          (wallet.walletId, wallet.descriptor, wallet.label),
          ('passphrase-1', 'wpkh(xpubPassphraseOne/<0;1>/*)', 'Vault'),
          reason: 'the stored wallet must survive the collision untouched',
        );
      },
    );
  });

  group('updatePassphraseLabelHint', () {
    setUp(
      () => repository.upsertPassphraseWallet(
        passphraseWalletEntry(hint: 'Old hint'),
      ),
    );

    test('a newer revision wins', () async {
      expect(
        await repository.updatePassphraseLabelHint(
          parentFingerprint: manifestFingerprint,
          walletId: 'passphrase-1',
          label: const KeychainManifestEdit('Renamed'),
          hint: const KeychainManifestEdit('New hint'),
          updatedAt: 9,
        ),
        isA<Ok<void, KeychainManifestFailure>>(),
      );

      final entry = await single();
      final wallet = entry.materializations.single as KeychainManifestWallet;
      expect(
        (wallet.label, entry.description, entry.updatedAt),
        ('Renamed', 'New hint', 9),
      );
    });

    test('an equal revision carrying other content is a conflict', () async {
      expect(
        await repository.updatePassphraseLabelHint(
          parentFingerprint: manifestFingerprint,
          walletId: 'passphrase-1',
          hint: const KeychainManifestEdit('Rival hint'),
          updatedAt: 2,
        ),
        isA<Err<void, KeychainManifestFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<KeychainManifestConflictFailure>(),
        ),
      );

      expect((await single()).description, 'Old hint');
    });

    test('an absent edit leaves that field alone', () async {
      await repository.updatePassphraseLabelHint(
        parentFingerprint: manifestFingerprint,
        walletId: 'passphrase-1',
        hint: const KeychainManifestEdit(null),
        updatedAt: 9,
      );

      final entry = await single();
      final wallet = entry.materializations.single as KeychainManifestWallet;
      expect((wallet.label, entry.description), ('Vault', null));
    });

    test('an unknown wallet is a conflict', () async {
      expect(
        await repository.updatePassphraseLabelHint(
          parentFingerprint: manifestFingerprint,
          walletId: 'never-existed',
          hint: const KeychainManifestEdit('New hint'),
          updatedAt: 9,
        ),
        isA<Err<void, KeychainManifestFailure>>(),
      );
    });
  });

  group('restoreSnapshot', () {
    test('applies a restored hint that is newer than the local one', () async {
      await repository.upsertPassphraseWallet(
        passphraseWalletEntry(hint: 'Old hint'),
      );

      final report = await repository.restoreSnapshot(
        manifest(
          entries: [
            passphraseWalletEntry(
              label: 'Renamed',
              hint: 'Restored hint',
              updatedAt: 7,
            ),
          ],
        ),
      );

      expect(_report(report).applied, 1);
      final entry = await single();
      final wallet = entry.materializations.single as KeychainManifestWallet;
      expect(
        (wallet.label, entry.description, entry.updatedAt),
        ('Renamed', 'Restored hint', 7),
      );
    });

    test('older restored text does not clobber newer local text', () async {
      await repository.upsertPassphraseWallet(
        passphraseWalletEntry(hint: 'Old hint'),
      );
      await repository.updatePassphraseLabelHint(
        parentFingerprint: manifestFingerprint,
        walletId: 'passphrase-1',
        hint: const KeychainManifestEdit('Local hint'),
        updatedAt: 20,
      );

      final report = await repository.restoreSnapshot(
        manifest(
          entries: [passphraseWalletEntry(hint: 'Stale hint', updatedAt: 7)],
          generatedAt: 21,
        ),
      );

      expect((_report(report).applied, _report(report).unchanged), (0, 1));
      expect((await single()).description, 'Local hint');
    });

    test('a different descriptor under one entry id is a conflict', () async {
      await repository.upsertPassphraseWallet(passphraseWalletEntry());

      final report = _report(
        await repository.restoreSnapshot(
          manifest(
            entries: [
              passphraseWalletEntry(
                walletId: 'passphrase-2',
                descriptor: 'wpkh(xpubPassphraseTwo/<0;1>/*)',
                label: 'Other',
                updatedAt: 9,
              ),
            ],
          ),
        ),
      );

      expect(report.conflicts, hasLength(1));
      expect(report.restored, 0);
      final wallet =
          (await single()).materializations.single as KeychainManifestWallet;
      expect(wallet.walletId, 'passphrase-1');
      expect(wallet.descriptor, 'wpkh(xpubPassphraseOne/<0;1>/*)');
    });

    test('an equal revision carrying other text is a conflict', () async {
      await repository.upsertPassphraseWallet(
        passphraseWalletEntry(hint: 'Old hint'),
      );

      final report = _report(
        await repository.restoreSnapshot(
          manifest(entries: [passphraseWalletEntry(hint: 'Rival hint')]),
        ),
      );

      expect(report.conflicts, hasLength(1));
      expect((await single()).description, 'Old hint');
    });

    test('inserts records the installation has never seen', () async {
      final report = _report(
        await repository.restoreSnapshot(
          manifest(entries: [passphraseWalletEntry(hint: 'Restored hint')]),
        ),
      );

      expect(report.applied, 1);
      expect((await single()).description, 'Restored hint');
    });
  });

  group('replaceSeedWalletInventory', () {
    test('keeps a passphrase record the re-derivation cannot see', () async {
      await repository.upsertPassphraseWallet(passphraseWalletEntry());

      expect(
        await repository.replaceSeedWalletInventory(manifestFingerprint, []),
        isA<Ok<void, KeychainManifestFailure>>(),
      );

      final wallet =
          (await single()).materializations.single as KeychainManifestWallet;
      expect(wallet.walletId, 'passphrase-1');
    });
  });

  group('removePassphraseWallet', () {
    test('forgets the record', () async {
      await repository.upsertPassphraseWallet(passphraseWalletEntry());

      expect(
        await repository.removePassphraseWallet(
          parentFingerprint: manifestFingerprint,
          walletId: 'passphrase-1',
        ),
        isA<Ok<void, KeychainManifestFailure>>(),
      );
      expect(await stored(), isEmpty);
    });

    test('reports a wallet that was never recorded', () async {
      expect(
        await repository.removePassphraseWallet(
          parentFingerprint: manifestFingerprint,
          walletId: 'never-existed',
        ),
        isA<Err<void, KeychainManifestFailure>>(),
      );
    });
  });

  group('Nostr key materialization', () {
    test('persists and reconstructs wallet and Nostr entries', () async {
      await repository.upsertPassphraseWallet(passphraseWalletEntry());
      expect(
        await repository.insertNostrKey(nostrManifestEntry()),
        isA<Ok<void, KeychainManifestFailure>>(),
      );

      final entries = await stored();
      expect(entries, hasLength(2));
      expect(
        entries.expand((entry) => entry.materializations),
        containsAll([
          isA<KeychainManifestWallet>(),
          isA<KeychainManifestNostrKey>(),
        ]),
      );
    });

    test('the same key written back changes nothing', () async {
      await repository.insertNostrKey(nostrManifestEntry());

      expect(
        await repository.insertNostrKey(nostrManifestEntry()),
        isA<Ok<void, KeychainManifestFailure>>(),
      );
      expect(await stored(), hasLength(1));
    });

    test('refuses a different key on a recorded derivation', () async {
      await repository.insertNostrKey(nostrManifestEntry());

      expect(
        await repository.insertNostrKey(
          nostrManifestEntry(publicKeyHex: 'a' * 64),
        ),
        isA<Err<void, KeychainManifestFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<KeychainManifestConflictFailure>(),
        ),
      );
    });

    test('updates user metadata atomically and monotonically', () async {
      final entry = nostrManifestEntry(description: 'old');
      await repository.insertNostrKey(entry);

      expect(
        await repository.updateNostrMetadata(
          parentFingerprint: manifestFingerprint,
          entryId: entry.entryId,
          purpose: 'new',
          description: 'new note',
          updatedAt: 1,
        ),
        isA<Ok<void, KeychainManifestFailure>>(),
      );

      final updatedEntry = await single();
      final updated =
          updatedEntry.materializations.single as KeychainManifestNostrKey;
      expect(
        (updated.purpose, updatedEntry.description, updated.updatedAt),
        ('new', 'new note', 3),
      );
    });
  });
}

KeychainManifestRestoreReport _report(
  Result<KeychainManifestRestoreReport, KeychainManifestFailure> result,
) => (result as Ok<KeychainManifestRestoreReport, KeychainManifestFailure>)
    .value;
