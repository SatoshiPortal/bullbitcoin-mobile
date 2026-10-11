import 'dart:typed_data';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/labels/frameworks/bip329_codec.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_metadata_backup.dart';
import '../backup_codec_fixture.dart';
import '../backup_snapshot_fixture.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_signer_device_port.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_signer_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_inventory_backup_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Importer extends Mock implements BitcoinDescriptorPort {}

class _Seeds extends Mock implements SeedVerificationPort {}

class _Vaults extends Fake implements BullVaultFacade {}

class _SignerDevices extends Fake implements WalletSignerDevicePort {}

void main() {
  late SqliteDatabase database;
  late WalletMetadataDatasource metadata;
  late _Importer importer;
  late _Seeds seeds;
  late WalletInventoryBackupRepositoryImpl inventory;
  var imports = 0;
  final key = WalletDescriptorKey(
    id: 'key-0',
    signerId: 'signer-0',
    masterFingerprint: 'aabbccdd',
    xpubFingerprint: '11223344',
    xpub: 'actual-xpub',
    derivationPath: 'm/84h/0h/0h',
    descriptorPath: '/<0;1>/*',
  );
  WalletSigner signer({String xpub = 'actual-xpub'}) => WalletSigner(
    id: 'signer-0',
    signer: SignerEntity.local,
    signerDevice: null,
    localSeedFingerprint: 'aabbccdd',
    descriptorKeys: [
      WalletDescriptorKey(
        id: key.id,
        signerId: key.signerId,
        masterFingerprint: key.masterFingerprint,
        xpubFingerprint: key.xpubFingerprint,
        xpub: xpub,
        derivationPath: key.derivationPath,
        descriptorPath: key.descriptorPath,
      ),
    ],
  );
  BackupWallet entry({
    String ref = 'source-id',
    String descriptor = 'public-descriptor',
    Network network = Network.bitcoinMainnet,
    String xpub = 'actual-xpub',
  }) => BackupWallet(
    reference: ref,
    network: network,
    publicDescriptor: descriptor,
    signers: [signer(xpub: xpub)],
    isDefault: true,
    isHidden: true,
    label: 'Recovered name',
    birthday: DateTime.utc(2020),
  );
  WalletMetadataModel stored(
    String id, {
    String descriptor = 'public-descriptor',
    Network network = Network.bitcoinMainnet,
    String? label = 'Local name',
  }) => WalletMetadataModel(
    id: id,
    network: network,
    signers: [signer().toModel()],
    publicDescriptor: descriptor,
    isDefault: true,
    label: label,
    isEncryptedVaultTested: false,
    isPhysicalBackupTested: false,
  );
  Future<WalletInventoryRecovery> recover(List<BackupWallet> entries) async =>
      (await inventory.restore(entries)
              as Ok<WalletInventoryRecovery, WalletBackupFailure>)
          .value;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    metadata = WalletMetadataDatasource(sqlite: database);
    importer = _Importer();
    seeds = _Seeds();
    imports = 0;
    when(
      () => importer.parseBitcoinDescriptor(
        descriptor: any(named: 'descriptor'),
        network: Network.bitcoinMainnet,
      ),
    ).thenAnswer(
      (call) => (
        descriptor: (call.namedArguments[#descriptor] as String).replaceAll(
          'alternate-form',
          'public-descriptor',
        ),
        scriptType: ScriptType.bip84,
        descriptorKeys: [key],
        inferredChangePath: false,
      ),
    );
    when(
      () => seeds.matchesXpubs(
        fingerprint: any(named: 'fingerprint'),
        keys: any(named: 'keys'),
      ),
    ).thenAnswer((_) async => false);
    when(
      () => importer.importDescriptor(
        descriptor: any(named: 'descriptor'),
        network: Network.bitcoinMainnet,
        label: any(named: 'label'),
        signers: any(named: 'signers'),
        isHidden: any(named: 'isHidden'),
      ),
    ).thenAnswer((call) async {
      imports++;
      final signers = call.namedArguments[#signers] as List<WalletSigner>;
      final record =
          stored(
            'target-id',
            descriptor: call.namedArguments[#descriptor] as String,
            label: call.namedArguments[#label] as String,
          ).copyWith(
            signers: signers.map((s) => s.toModel()).toList(),
            isDefault: false,
            isHidden: call.namedArguments[#isHidden] as bool,
          );
      await metadata.store(record);
      return Wallet(
        origin: record.id,
        network: record.network,
        signers: signers,
        scriptType: ScriptType.bip84,
        publicDescriptor: record.publicDescriptor,
        balanceSat: BigInt.zero,
      );
    });
    inventory = WalletInventoryBackupRepositoryImpl(
      database: database,
      vaults: _Vaults(),
      signerDevices: _SignerDevices(),
      wallets: metadata,
      descriptors: importer,
      seeds: seeds,
    );
  });
  tearDown(() => database.close());

  for (final edited in [false, true]) {
    test(
      'physical recovery restores a new default label only if still unchanged: edited=$edited',
      () async {
        await metadata.store(
          stored('new-default', label: edited ? 'My edit' : null),
        );
        final result = await inventory.restore(
          [entry()],
          initialWalletLabels: {'new-default': null},
        );
        expect(
          (result as Ok<WalletInventoryRecovery, WalletBackupFailure>)
              .value
              .complete,
          isTrue,
        );
        expect(
          (await metadata.fetch('new-default'))!.label,
          edited ? 'My edit' : 'Recovered name',
        );
        expect(imports, 0);
      },
    );
  }
  test(
    'imports through the upstream owner and remaps without inventing a default or local key',
    () async {
      final result = await recover([entry()]);
      expect(result.complete, isTrue);
      expect(result.walletReferences, {'source-id': 'target-id'});
      final wallet = (await metadata.fetch('target-id'))!;
      expect(wallet.isDefault, isFalse);
      expect(wallet.label, 'Recovered name');
      expect(wallet.birthday, DateTime.utc(2020));
      expect(wallet.signers.single.toEntity().signer, SignerEntity.none);
      expect(wallet.signers.single.localSeedFingerprint, isNull);
    },
  );
  test(
    'matches a canonical descriptor under a different ID without replacing local preferences',
    () async {
      await metadata.store(stored('existing-id'));
      final result = await recover([entry(descriptor: 'alternate-form')]);
      expect(result.walletReferences, {'source-id': 'existing-id'});
      expect(imports, 0);
      expect((await metadata.fetch('existing-id'))!.label, 'Local name');
    },
  );
  test('retry preserves a name edited after the first recovery', () async {
    await recover([entry()]);
    final first = (await metadata.fetch('target-id'))!;
    await metadata.store(first.copyWith(label: 'Edited locally'));
    final retry = await recover([entry()]);
    expect(retry.complete, isTrue);
    expect(imports, 1);
    expect((await metadata.fetch('target-id'))!.label, 'Edited locally');
  });
  test('only a verified actual descriptor key may become local', () async {
    when(
      () => seeds.matchesXpubs(
        fingerprint: 'aabbccdd',
        keys: any(named: 'keys'),
      ),
    ).thenAnswer((call) async {
      expect(call.namedArguments[#keys], [
        (derivationPath: key.derivationPath!, xpub: key.xpub),
      ]);
      return true;
    });
    expect((await recover([entry()])).complete, isTrue);
    expect(
      (await metadata.fetch('target-id'))!.signers.single.toEntity().signer,
      SignerEntity.local,
    );
  });
  for (final hasSeed in [true, false]) {
    test(
      'encrypted external 2-of-3 recovery verifies local keys (seed: $hasSeed)',
      () async {
        final seed = Uint8List.fromList(List.generate(32, (i) => i));
        const path = "m/48'/0'/0'/2'";
        final xpubs = [
          for (var n = 0; n < 3; n++)
            Bip32Derivation.deriveXpub(
              seedBytes: Uint8List.fromList(List.generate(32, (i) => i + n)),
              derivationPath: path,
              network: Network.bitcoinMainnet,
            ),
        ];
        const fingerprints = ['5a3469b6', 'cafebabe', 'feedbeef'];
        final descriptor =
            'wsh(sortedmulti(2,${[for (var n = 0; n < 3; n++) '[${fingerprints[n]}/48h/0h/0h/2h]${xpubs[n]}/<0;1>/*'].join(',')}))';
        final parsed = BdkFacade.parsePublicTwoPathDescriptor(
          descriptor: descriptor,
          isTestnet: false,
        );
        final keys = [
          for (final (index, key) in parsed.keys.indexed)
            WalletDescriptorKey(
              id: 'key-$index',
              signerId: 'signer-$index',
              masterFingerprint: key.masterFingerprint,
              xpubFingerprint: key.xpubFingerprint,
              xpub: key.xpub,
              derivationPath: key.derivationPath,
              descriptorPath: key.descriptorPath,
            ),
        ];
        when(
          () => importer.parseBitcoinDescriptor(
            descriptor: any(named: 'descriptor'),
            network: Network.bitcoinMainnet,
          ),
        ).thenReturn((
          descriptor: parsed.descriptor,
          scriptType: null,
          descriptorKeys: keys,
          inferredChangePath: false,
        ));
        when(
          () => seeds.matchesXpubs(
            fingerprint: any(named: 'fingerprint'),
            keys: any(named: 'keys'),
          ),
        ).thenAnswer(
          (call) async =>
              hasSeed &&
              call.namedArguments[#fingerprint] == fingerprints.first &&
              (call.namedArguments[#keys]
                      as List<({String derivationPath, String xpub})>)
                  .every(
                    (key) => Bip32Derivation.seedMatchesXpub(
                      seedBytes: seed,
                      derivationPath: key.derivationPath,
                      xpub: key.xpub,
                    ),
                  ),
        );
        final credential = BackupCredential.fromWords(backupFixtureWords);
        final base = backupSnapshotFixture(credential, populated: false);
        final memo = LabelEntity(
          id: 1,
          type: LabelType.extendedPublicKey,
          reference: xpubs.first,
          label: 'External family multisig',
          origin: '[${fingerprints.first}/48h/0h/0h/2h]',
        );
        final snapshot = WalletBackupSnapshot(
          manifest: KeychainManifest(
            sourceFingerprint: base.manifest.sourceFingerprint,
            wallets: [
              BackupWallet(
                reference: 'source-multisig',
                network: Network.bitcoinMainnet,
                publicDescriptor: parsed.descriptor,
                signers: [
                  for (final key in keys)
                    WalletSigner(
                      id: key.signerId,
                      signer: key.xpub == xpubs.first
                          ? SignerEntity.local
                          : SignerEntity.none,
                      signerDevice: null,
                      localSeedFingerprint: key.xpub == xpubs.first
                          ? fingerprints.first
                          : null,
                      descriptorKeys: [key],
                    ),
                ],
                isDefault: false,
                isHidden: false,
                label: 'External family multisig',
              ),
            ],
            derivations: [],
            nostrKeys: [],
            backupIdentities: base.manifest.backupIdentities,
          ),
          metadata: WalletMetadataBackup(
            labels: [memo],
            frozenOutputs: [],
            settings: base.metadata.settings,
          ),
          vaults: [],
        );
        final codec = backupCodecFixture(_Vaults());
        addTearDown(codec.dispose);
        final encrypted = (codec.encrypt(snapshot, credential) as Ok).value;
        final restored =
            (codec.decrypt(encrypted, credential)
                    as Ok<WalletBackupSnapshot, WalletBackupFailure>)
                .value;
        expect(await metadata.fetchAll(), isEmpty);
        expect((await recover(restored.manifest.wallets)).complete, isTrue);
        final wallet = (await metadata.fetch('target-id'))!;
        final local = wallet.signers
            .map((s) => s.toEntity())
            .where((s) => s.signer == SignerEntity.local)
            .toList();
        expect(local.length, hasSeed ? 1 : 0);
        if (hasSeed) {
          expect(local.single.localSeedFingerprint, fingerprints.first);
        }
        expect(wallet.signers, hasLength(3));
        expect(wallet.publicDescriptor, parsed.descriptor);
        expect(wallet.label, 'External family multisig');
        expect(restored.metadata.labels.single.origin, memo.origin);
        expect(restored.metadata.labels.single.label, memo.label);
        // The existing BIP-329 export remains valid; Data Backup preserves the origin.
        final labelsCodec = Bip329LabelsCodec();
        final labels = labelsCodec.decode(
          labelsCodec.encode(restored.metadata.labels),
        );
        expect(labels.labels.single.reference, xpubs.first);
        expect(labels.labels.single.label, memo.label);
      },
    );
  }

  test(
    'forged key annotations fail before importing or checking a substitute xpub',
    () async {
      final result = await recover([entry(xpub: 'forged-xpub')]);
      expect(result.failedReferences, ['source-id']);
      expect(imports, 0);
      verifyNever(
        () => seeds.matchesXpubs(
          fingerprint: any(named: 'fingerprint'),
          keys: any(named: 'keys'),
        ),
      );
    },
  );
  test(
    'existing Liquid wallets map; missing Liquid stays incomplete',
    () async {
      await metadata.store(
        stored(
          'liquid-local',
          descriptor: 'liquid-existing',
          network: Network.liquidMainnet,
        ),
      );
      final result = await recover([
        entry(
          ref: 'liquid-source',
          descriptor: 'liquid-existing',
          network: Network.liquidMainnet,
        ),
        entry(
          ref: 'missing',
          descriptor: 'liquid-other',
          network: Network.liquidMainnet,
        ),
      ]);
      expect(result.walletReferences, {'liquid-source': 'liquid-local'});
      expect(result.failedReferences, ['missing']);
      expect(imports, 0);
    },
  );
  test(
    'ambiguous matches and conflicting occupied IDs remain incomplete',
    () async {
      await metadata.store(stored('first'));
      await metadata.store(stored('second'));
      expect((await recover([entry()])).complete, isFalse);
      await metadata.delete('second');
      await metadata.store(stored('source-id', descriptor: 'other-descriptor'));
      expect(
        (await recover([entry(descriptor: 'third-descriptor')])).complete,
        isFalse,
      );
      expect(imports, 0);
    },
  );
  test('one failure does not hide successfully resolved wallets', () async {
    final result = await recover([
      entry(),
      entry(ref: 'missing', network: Network.liquidMainnet),
    ]);
    expect(result.walletReferences, {'source-id': 'target-id'});
    expect(result.failedReferences, ['missing']);
    expect(result.complete, isFalse);
  });
}
