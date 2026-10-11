import 'package:bb_mobile/core/bip85/data/bip85_datasource.dart';
import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/keychain_manifest/data/keychain_manifest_repository_impl.dart';
import 'package:bb_mobile/features/keychain_manifest/data/nostr_key_repository_impl.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SqliteDatabase db;
  late Bip85Datasource bip85;
  late NostrKeyRepositoryImpl nostr;
  late KeychainManifestRepositoryImpl repository;
  NostrKeyRecord key(String publicKey, {String purpose = 'Recovered'}) =>
      NostrKeyRecord(
        parentFingerprint: 'aabbccdd',
        identity: 1,
        publicKey: publicKey,
        purpose: purpose,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
  KeychainManifest manifest() => KeychainManifest(
    sourceFingerprint: 'aabbccdd',
    wallets: [],
    derivations: [
      Bip85DerivationEntity(
        path: "39'/0'/12'/4'",
        xprvFingerprint: 'aabbccdd',
        alias: 'Child',
        status: Bip85Status.active,
        application: Bip85Application.bip39,
        index: 4,
      ),
    ],
    nostrKeys: [key('1' * 64)],
    backupIdentities: [
      BackupIdentityRecord(
        parentFingerprint: 'aabbccdd',
        publicKey: '2' * 64,
        kind: BackupIdentityKind.artifact,
      ),
      BackupIdentityRecord(
        parentFingerprint: 'aabbccdd',
        publicKey: '3' * 64,
        kind: BackupIdentityKind.server,
      ),
    ],
  );
  setUp(() {
    db = SqliteDatabase(NativeDatabase.memory());
    bip85 = Bip85Datasource(sqlite: db);
    nostr = NostrKeyRepositoryImpl(db);
    repository = KeychainManifestRepositoryImpl(
      database: db,
      wallets: WalletMetadataDatasource(sqlite: db),
      bip85: Bip85Repository(datasource: bip85),
      nostrKeys: nostr,
    );
  });
  tearDown(() => db.close());
  test(
    'restores public catalogs and safely replays existing records',
    () async {
      expect(await repository.restorePublicRecords(manifest()), isA<Ok>());
      expect((await bip85.fetchAll()).single.alias, 'Child');
      final records = await nostr.getAll();
      expect((records as Ok).value, hasLength(1));
      expect(await repository.restorePublicRecords(manifest()), isA<Ok>());
      expect(await bip85.fetchAll(), hasLength(1));
    },
  );
  test(
    'Nostr collision rolls back the preceding public BIP85 insert',
    () async {
      expect(await nostr.insert(key('4' * 64, purpose: 'Local')), isA<Ok>());
      expect(await repository.restorePublicRecords(manifest()), isA<Err>());
      expect(await bip85.fetchAll(), isEmpty);
      final records =
          (await nostr.getAll()
                  as Ok<List<NostrKeyRecord>, KeychainManifestFailure>)
              .value;
      expect(records.single.publicKey, '4' * 64);
      expect(records.single.purpose, 'Local');
    },
  );
  test('an existing local Nostr description is preserved', () async {
    expect(await nostr.insert(key('1' * 64, purpose: 'Local')), isA<Ok>());
    expect(await repository.restorePublicRecords(manifest()), isA<Ok>());
    final records =
        (await nostr.getAll()
                as Ok<List<NostrKeyRecord>, KeychainManifestFailure>)
            .value;
    expect(records.single.purpose, 'Local');
  });
}
