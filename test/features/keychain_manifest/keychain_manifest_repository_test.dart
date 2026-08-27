import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/keychain_manifest/data/keychain_manifest_repository_impl.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'support/manifest_fixtures.dart';

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

  test('persists and reconstructs wallet and Nostr entries', () async {
    final entries = [walletManifestEntry(), nostrManifestEntry()];
    expect(
      await repository.save(entries),
      isA<Ok<void, KeychainManifestFailure>>(),
    );

    final fetched = await repository.fetch(manifestFingerprint);
    final value =
        (fetched as Ok<List<KeychainManifestEntry>, KeychainManifestFailure>)
            .value;
    expect(value, hasLength(2));
    expect(value.first.reservationId, 'nostr_user_key');
    expect(
      value.expand((entry) => entry.materializations),
      containsAll([
        isA<KeychainManifestWallet>(),
        isA<KeychainManifestNostrKey>(),
      ]),
    );
  });

  test('same append is idempotent', () async {
    final entry = walletManifestEntry();
    expect(
      await repository.save([entry]),
      isA<Ok<void, KeychainManifestFailure>>(),
    );
    expect(
      await repository.save([entry]),
      isA<Ok<void, KeychainManifestFailure>>(),
    );
    final fetched = await repository.fetch(manifestFingerprint);
    expect(
      (fetched as Ok<List<KeychainManifestEntry>, KeychainManifestFailure>)
          .value,
      hasLength(1),
    );
  });

  test('refuses a wallet id bound to different seed material', () async {
    final entry = walletManifestEntry();
    await repository.save([entry]);
    final conflicting = entry.withMaterializations([
      KeychainManifestWallet(
        walletId: 'wallet-1',
        entryId: entry.entryId,
        childSeedFingerprint: Fingerprint('00000000'),
        network:
            (entry.materializations.single as KeychainManifestWallet).network,
        scriptType: (entry.materializations.single as KeychainManifestWallet)
            .scriptType,
        createdAt: 1,
        updatedAt: 2,
      ),
    ]);
    expect(
      await repository.save([conflicting]),
      isA<Err<void, KeychainManifestFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<KeychainManifestConflictFailure>(),
      ),
    );
  });

  test('updates user metadata atomically and monotonically', () async {
    final entry = nostrManifestEntry(description: 'old');
    await repository.save([entry]);
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
    final fetched = await repository.fetch(manifestFingerprint);
    final updated =
        (fetched as Ok<List<KeychainManifestEntry>, KeychainManifestFailure>)
                .value
                .single
                .materializations
                .single
            as KeychainManifestNostrKey;
    expect(
      (updated.purpose, updated.description, updated.updatedAt),
      ('new', 'new note', 3),
    );
  });
}
