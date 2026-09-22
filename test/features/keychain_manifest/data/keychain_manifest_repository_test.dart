import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_signer_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_descriptor_key_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/data/keychain_manifest_repository_impl.dart';
import 'package:bb_mobile/features/keychain_manifest/data/nostr_key_repository_impl.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bip85 extends Mock implements Bip85Repository {}

void main() {
  late SqliteDatabase database;
  late WalletMetadataDatasource wallets;
  late NostrKeyRepositoryImpl nostr;
  late KeychainManifestRepositoryImpl repository;
  final birthday = DateTime.utc(2020, 1, 2);
  WalletMetadataModel wallet(
    String id, {
    Network network = Network.bitcoinMainnet,
    String? label,
    bool isDefault = false,
  }) => WalletMetadataModel(
    id: id,
    network: network,
    publicDescriptor: 'wpkh([aabbccdd/84h/0h/0h]xpub-fixture/<0;1>/*)#checksum',
    signers: [
      const WalletSignerModel(
        id: 'signer-0',
        signer: Signer.remote,
        signerDevice: SignerDevice.ledgerNanoX,
        registrationName: 'My device',
        descriptorKeys: [
          WalletDescriptorKeyModel(
            id: 'key-0',
            signerId: 'signer-0',
            masterFingerprint: 'aabbccdd',
            xpubFingerprint: '11223344',
            xpub: 'xpub-fixture',
            derivationPath: "84'/0'/0'",
            descriptorPath: '/<0;1>/*',
          ),
        ],
      ),
    ],
    isEncryptedVaultTested: false,
    isPhysicalBackupTested: false,
    isDefault: isDefault,
    isHidden: true,
    label: label,
    birthday: birthday,
  );
  setUp(() async {
    database = SqliteDatabase(NativeDatabase.memory());
    wallets = WalletMetadataDatasource(sqlite: database);
    nostr = NostrKeyRepositoryImpl(database);
    final bip85 = _Bip85();
    when(() => bip85.fetchAll()).thenAnswer(
      (_) async => Ok([
        Bip85DerivationEntity(
          path: "39'/0'/12'/5'",
          xprvFingerprint: 'aabbccdd',
          alias: 'Child',
          status: Bip85Status.active,
          application: Bip85Application.bip39,
          index: 5,
        ),
        Bip85DerivationEntity(
          path: "39'/0'/12'/6'",
          xprvFingerprint: 'eeff0011',
          alias: 'Other root',
          status: Bip85Status.active,
          application: Bip85Application.bip39,
          index: 6,
        ),
      ]),
    );
    repository = KeychainManifestRepositoryImpl(
      database: database,
      wallets: wallets,
      bip85: bip85,
      nostrKeys: nostr,
    );
  });
  tearDown(() => database.close());
  Future<CapturedKeychainManifest> capture() async =>
      (await repository.capture(
                sourceFingerprint: 'aabbccdd',
                artifactPublicKey: '1' * 64,
                serverPublicKey: '2' * 64,
              )
              as Ok<CapturedKeychainManifest, KeychainManifestFailure>)
          .value;
  test(
    'mixed inventory uses existing public facts and scopes key records to their real origin',
    () async {
      await wallets.store(wallet('first', label: 'External', isDefault: true));
      await wallets.store(wallet('testnet', network: Network.bitcoinTestnet));
      for (final (origin, publicKey) in [
        ('aabbccdd', '3'),
        ('eeff0011', '4'),
      ]) {
        expect(
          await nostr.insert(
            NostrKeyRecord(
              parentFingerprint: origin,
              identity: 1,
              publicKey: publicKey * 64,
              purpose: 'Public identity',
              createdAt: birthday,
              updatedAt: birthday,
            ),
          ),
          isA<Ok>(),
        );
      }
      final result = await capture();
      final manifest = result.manifest;
      expect(manifest.wallets, hasLength(2));
      final entry = manifest.wallets.singleWhere(
        (wallet) => wallet.network == Network.bitcoinMainnet,
      );
      expect(entry.label, 'External');
      expect(entry.birthday, birthday);
      expect(entry.isDefault, isTrue);
      expect(entry.isHidden, isTrue);
      expect(entry.signers.single.registrationName, 'My device');
      expect(
        manifest.wallets
            .singleWhere((wallet) => wallet.network == Network.bitcoinTestnet)
            .label,
        isNull,
      );
      expect(manifest.derivations.single.alias, 'Child');
      expect(manifest.nostrKeys.single.parentFingerprint, 'aabbccdd');
      expect(manifest.backupIdentities.map((key) => key.publicKey), [
        '1' * 64,
        '2' * 64,
      ]);
      expect(result.walletReferences['first'], entry.reference);
      expect(result.walletReferences.values.toSet(), hasLength(2));
    },
  );
  test(
    'backup references preserve upstream IDs for package links without requiring the target to reuse them',
    () async {
      await wallets.store(wallet('old'));
      final first = await capture();
      await wallets.delete('old');
      await wallets.store(
        wallet('new').copyWith(
          publicDescriptor: wallet('old').publicDescriptor.split('#').first,
          birthday: null,
        ),
      );
      final second = await capture();
      expect(first.manifest.wallets.single.reference, 'old');
      expect(second.manifest.wallets.single.reference, 'new');
      expect(second.walletReferences.keys, ['new']);
      expect(second.manifest.wallets.single.birthday, isNull);
    },
  );
  test(
    'storage errors fail capture rather than uploading an empty inventory',
    () async {
      await database.customStatement('DROP TABLE wallet_metadatas');
      expect(
        await repository.capture(
          sourceFingerprint: 'aabbccdd',
          artifactPublicKey: '1' * 64,
          serverPublicKey: '2' * 64,
        ),
        isA<Err>(),
      );
    },
  );
}
