import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_metadata_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_descriptor_key_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_signer_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../wallet_signer_test_fixture.dart';

final _mobile = walletSignerModel(
  id: 'signer-0',
  descriptorKeyId: 'key-0',
  masterFingerprint: '11111111',
  xpubFingerprint: '11111112',
  xpub: 'xpub-mobile',
  derivationPath: "m/48'/1'/0'/2'",
  signer: Signer.local,
  signerDevice: null,
);
final _hardware = walletSignerModel(
  id: 'signer-1',
  descriptorKeyId: 'key-1',
  masterFingerprint: '22222222',
  xpubFingerprint: '22222223',
  xpub: 'xpub-hardware',
  derivationPath: "m/48'/1'/0'/2'",
  signer: Signer.remote,
  signerDevice: SignerDevice.jade,
);
final _server = walletSignerModel(
  id: 'signer-2',
  descriptorKeyId: 'key-2',
  masterFingerprint: '33333333',
  xpubFingerprint: '33333334',
  xpub: 'xpub-server',
  derivationPath: "m/48'/1'/0'/2'",
  signer: Signer.none,
  signerDevice: null,
);

void main() {
  late SqliteDatabase database;
  late WalletMetadataDatasource datasource;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    datasource = WalletMetadataDatasource(sqlite: database);
  });

  tearDown(() => database.close());

  test('stores and fetches ordered signers and descriptor keys', () async {
    final metadata = _multisigMetadata();

    await datasource.store(metadata);

    final storedMetadata = await datasource.fetch(metadata.id);
    expect(storedMetadata, metadata);
    expect(storedMetadata!.inferredScriptType, isNull);
    final walletRow = await database
        .select(database.walletMetadatas)
        .getSingle();
    expect(walletRow.network, Network.bitcoinTestnet);

    final signerRows = await database.select(database.walletSigners).get();
    signerRows.sort((a, b) => a.position.compareTo(b.position));
    expect(signerRows.map((row) => row.position), [0, 1, 2]);
    final keyRows = await database.select(database.walletDescriptorKeys).get();
    keyRows.sort((a, b) => a.position.compareTo(b.position));
    expect(keyRows.map((row) => row.xpub), [
      'xpub-mobile',
      'xpub-hardware',
      'xpub-server',
    ]);
    expect(
      keyRows.map((row) => row.derivationPath),
      everyElement("m/48'/1'/0'/2'"),
    );
  });

  test('replaces signer and descriptor-key rows together', () async {
    final metadata = _multisigMetadata();
    await datasource.store(metadata);

    final updated = metadata.copyWith(signers: [_mobile]);
    await datasource.store(updated);

    expect(await datasource.fetch(metadata.id), updated);
    final signerRows = await database.select(database.walletSigners).get();
    final keyRows = await database.select(database.walletDescriptorKeys).get();
    expect(signerRows, hasLength(1));
    expect(keyRows, hasLength(1));
    expect(signerRows.single.position, 0);
    expect(keyRows.single.xpub, _mobile.descriptorKeys.single.xpub);
  });

  test('updates sync time without replacing signer metadata', () async {
    final metadata = _multisigMetadata();
    final syncedAt = DateTime.utc(2026, 8, 26);
    await datasource.store(metadata);

    await datasource.updateSyncedAt(walletId: metadata.id, syncedAt: syncedAt);

    expect(
      await datasource.fetch(metadata.id),
      metadata.copyWith(syncedAt: syncedAt),
    );
  });

  test('stores one xpub at distinct descriptor paths', () async {
    final metadata = _multisigMetadata().copyWith(
      signers: [
        WalletSignerModel(
          id: _mobile.id,
          signer: _mobile.signer,
          signerDevice: _mobile.signerDevice,
          descriptorKeys: [
            _mobile.descriptorKeys.single,
            WalletDescriptorKeyModel(
              id: 'key-3',
              signerId: _mobile.id,
              masterFingerprint:
                  _mobile.descriptorKeys.single.masterFingerprint,
              xpubFingerprint: _mobile.descriptorKeys.single.xpubFingerprint,
              xpub: _mobile.descriptorKeys.single.xpub,
              derivationPath: _mobile.descriptorKeys.single.derivationPath,
              descriptorPath: '/1/<0;1>/*',
            ),
          ],
        ),
      ],
    );

    await datasource.store(metadata);

    final stored = await datasource.fetch(metadata.id);
    expect(stored, metadata);
    expect(stored!.signers, hasLength(1));
    expect(stored.signers.single.descriptorKeys.map((key) => key.xpub), [
      _mobile.descriptorKeys.single.xpub,
      _mobile.descriptorKeys.single.xpub,
    ]);
    expect(
      stored.signers.single.descriptorKeys.map((key) => key.descriptorPath),
      ['', '/1/<0;1>/*'],
    );
  });

  test('updates only the selected signer device annotation', () async {
    final metadata = _multisigMetadata();
    await datasource.store(metadata);

    final didUpdate = await datasource.updateSignerDevice(
      walletId: metadata.id,
      signerId: _hardware.id,
      signer: Signer.remote,
      signerDevice: SignerDevice.ledgerFlex,
    );

    final stored = await datasource.fetch(metadata.id);
    expect(didUpdate, isTrue);
    expect(stored!.signers[1].signerDevice, SignerDevice.ledgerFlex);
    expect(stored.signers[0], _mobile);
    expect(stored.signers[2], _server);
    expect(stored.publicDescriptor, metadata.publicDescriptor);
  });

  test('deletes signers and descriptor keys with wallet metadata', () async {
    final metadata = _multisigMetadata();
    await datasource.store(metadata);

    await datasource.delete(metadata.id);

    expect(await database.select(database.walletMetadatas).get(), isEmpty);
    expect(await database.select(database.walletSigners).get(), isEmpty);
    expect(await database.select(database.walletDescriptorKeys).get(), isEmpty);
  });
}

WalletMetadataModel _multisigMetadata() => WalletMetadataModel(
  id: 'wsh(sortedmulti(2,test))',
  network: Network.bitcoinTestnet,
  signers: [_mobile, _hardware, _server],
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  publicDescriptor:
      'wsh(sortedmulti(2,xpub-mobile,xpub-hardware,xpub-server))#descriptor',
  isDefault: false,
  label: 'Vault',
);
