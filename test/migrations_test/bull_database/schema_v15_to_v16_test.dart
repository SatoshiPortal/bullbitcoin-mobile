import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v15.dart' as v15;
import 'generated/schema_v16.dart' as v16;

typedef _LegacyWallet = ({
  String id,
  String network,
  String masterFingerprint,
  String xpubFingerprint,
  String xpub,
  String derivationPath,
  String externalDescriptor,
  String internalDescriptor,
  String signer,
  String? signerDevice,
});

final _wallets = _legacyWallets();

List<_LegacyWallet> _legacyWallets() {
  const mainWords =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  const testWords =
      'legal winner thank year wave sausage worth useful legal winner thank yellow';
  final legacy = _standardWallet(
    mainWords,
    scriptType: ScriptType.bip44,
    isTestnet: false,
  );
  final nestedSegwit = _standardWallet(
    testWords,
    scriptType: ScriptType.bip49,
    isTestnet: true,
  );
  final nativeSegwit = _standardWallet(
    testWords,
    scriptType: ScriptType.bip84,
    isTestnet: false,
  );

  const liquidMainDescriptor =
      'ct(elwpkh([33333333/84h/1776h/0h]xpub-liquid-mainnet/<0;1>/*))#descriptor';
  const liquidTestDescriptor =
      'ct(elwpkh([44444444/84h/1h/0h]tpub-liquid-testnet/<0;1>/*))#descriptor';

  return [
    (
      id: 'pkh([${legacy.masterFingerprint}/44h/0h/0h])',
      network: 'bitcoinMainnet',
      masterFingerprint: legacy.masterFingerprint,
      xpubFingerprint: legacy.xpubFingerprint,
      xpub: legacy.xpub,
      derivationPath: "m/44'/0'/0'",
      externalDescriptor: legacy.externalDescriptor,
      internalDescriptor: legacy.internalDescriptor,
      signer: 'local',
      signerDevice: null,
    ),
    (
      id: "sh(wpkh([${nestedSegwit.masterFingerprint}/49'/1'/0']))",
      network: 'bitcoinTestnet',
      masterFingerprint: '',
      xpubFingerprint: nestedSegwit.xpubFingerprint,
      xpub: nestedSegwit.xpub,
      derivationPath: "m/49'/1'/0'",
      externalDescriptor: nestedSegwit.externalDescriptor,
      internalDescriptor: nestedSegwit.internalDescriptor,
      signer: 'none',
      signerDevice: null,
    ),
    (
      id: 'elwpkh([33333333/84h/1776h/0h])',
      network: 'liquidMainnet',
      masterFingerprint: '33333333',
      xpubFingerprint: '33333334',
      xpub: 'xpub-liquid-mainnet',
      derivationPath: "m/84'/1776'/0'",
      externalDescriptor: liquidMainDescriptor,
      internalDescriptor: liquidMainDescriptor,
      signer: 'local',
      signerDevice: null,
    ),
    (
      id: 'elwpkh([44444444/84h/1h/0h])',
      network: 'liquidTestnet',
      masterFingerprint: '44444444',
      xpubFingerprint: '44444445',
      xpub: 'tpub-liquid-testnet',
      derivationPath: "m/84'/1'/0'",
      externalDescriptor: liquidTestDescriptor,
      internalDescriptor: liquidTestDescriptor,
      signer: 'remote',
      signerDevice: 'jade',
    ),
    (
      id: 'wpkh([${nativeSegwit.masterFingerprint}/84h/0h/0h])',
      network: 'bitcoinMainnet',
      masterFingerprint: nativeSegwit.masterFingerprint,
      xpubFingerprint: nativeSegwit.xpubFingerprint,
      xpub: nativeSegwit.xpub,
      derivationPath: "m/84'/0'/0'",
      externalDescriptor: nativeSegwit.externalDescriptor,
      internalDescriptor: nativeSegwit.internalDescriptor,
      signer: 'remote',
      signerDevice: 'ledgerNanoX',
    ),
  ];
}

({
  String externalDescriptor,
  String internalDescriptor,
  String masterFingerprint,
  String xpub,
  String xpubFingerprint,
})
_standardWallet(
  String words, {
  required ScriptType scriptType,
  required bool isTestnet,
}) {
  final networkKind = isTestnet ? bdk.NetworkKind.test : bdk.NetworkKind.main;
  final coinType = isTestnet ? 1 : 0;
  final root = bdk.DescriptorSecretKey(
    networkKind: networkKind,
    mnemonic: bdk.Mnemonic.fromString(mnemonic: words),
    password: null,
  );
  final account = root.derive(
    path: bdk.DerivationPath(path: "m/${scriptType.purpose}'/$coinType'/0'"),
  );
  final (external, internal) = switch (scriptType) {
    ScriptType.bip44 => (
      bdk.Descriptor.newBip44(
        secretKey: root,
        keychainKind: bdk.KeychainKind.external_,
        networkKind: networkKind,
      ),
      bdk.Descriptor.newBip44(
        secretKey: root,
        keychainKind: bdk.KeychainKind.internal,
        networkKind: networkKind,
      ),
    ),
    ScriptType.bip49 => (
      bdk.Descriptor.newBip49(
        secretKey: root,
        keychainKind: bdk.KeychainKind.external_,
        networkKind: networkKind,
      ),
      bdk.Descriptor.newBip49(
        secretKey: root,
        keychainKind: bdk.KeychainKind.internal,
        networkKind: networkKind,
      ),
    ),
    ScriptType.bip84 => (
      bdk.Descriptor.newBip84(
        secretKey: root,
        keychainKind: bdk.KeychainKind.external_,
        networkKind: networkKind,
      ),
      bdk.Descriptor.newBip84(
        secretKey: root,
        keychainKind: bdk.KeychainKind.internal,
        networkKind: networkKind,
      ),
    ),
  };
  return (
    externalDescriptor: external.toString(),
    internalDescriptor: internal.toString(),
    masterFingerprint: root.asPublic().masterFingerprint(),
    xpub: account.asPublic().toString(),
    xpubFingerprint: account.asPublic().masterFingerprint(),
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v15 wallets retain descriptors and normalize signer data', () async {
    final schema = await verifier.schemaAt(15);
    final oldDb = v15.DatabaseAtV15(schema.newConnection());
    for (final (index, wallet) in _wallets.indexed) {
      await _insertLegacyWallet(oldDb, wallet, index);
    }
    await oldDb.close();

    final db = SqliteDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 16);
    await db.close();

    final migratedDb = v16.DatabaseAtV16(schema.newConnection());
    final metadataRows = await migratedDb
        .select(migratedDb.walletMetadatas)
        .get();
    final signerRows = await migratedDb.select(migratedDb.walletSigners).get();
    final keyRows = await migratedDb
        .select(migratedDb.walletDescriptorKeys)
        .get();

    expect(metadataRows, hasLength(_wallets.length));
    expect(signerRows, hasLength(_wallets.length));
    expect(keyRows, hasLength(_wallets.length));
    for (final (index, wallet) in _wallets.indexed) {
      final metadata = metadataRows.singleWhere((row) => row.id == wallet.id);
      expect(metadata.id, wallet.id);
      expect(metadata.network, wallet.network);
      expect(metadata.publicDescriptor, _expectedDescriptor(wallet));
      if (wallet.network.startsWith('bitcoin')) {
        final expanded = _expandBitcoinDescriptor(
          metadata.publicDescriptor,
          isTestnet: wallet.network == 'bitcoinTestnet',
        );
        expect(expanded.external, wallet.externalDescriptor);
        expect(expanded.internal, wallet.internalDescriptor);
      }
      expect(metadata.isEncryptedVaultTested, index.isEven ? 1 : 0);
      expect(metadata.isPhysicalBackupTested, index.isOdd ? 1 : 0);
      expect(
        metadata.latestEncryptedBackup,
        index.isEven ? 1680000000 + index : null,
      );
      expect(
        metadata.latestPhysicalBackup,
        index.isOdd ? 1681000000 + index : null,
      );
      expect(metadata.isDefault, index == 0 ? 1 : 0);
      expect(metadata.isHidden, 0);
      expect(metadata.label, index.isEven ? 'wallet-$index' : null);
      expect(
        metadata.syncedAt,
        index.isEven ? '2026-08-0${index + 1}T00:00:00.000Z' : null,
      );
      expect(
        metadata.birthday,
        index.isOdd ? '2025-08-0${index + 1}T00:00:00.000Z' : null,
      );

      final signer = signerRows.singleWhere((row) => row.walletId == wallet.id);
      final key = keyRows.singleWhere((row) => row.walletId == wallet.id);
      expect(signer.id, 'signer-0');
      expect(signer.position, 0);
      expect(signer.signer, wallet.signer);
      expect(signer.signerDevice, wallet.signerDevice);
      expect(key.id, 'key-0');
      expect(key.signerId, signer.id);
      expect(key.position, 0);
      expect(key.masterFingerprint, wallet.masterFingerprint);
      expect(key.xpubFingerprint, wallet.xpubFingerprint);
      expect(key.xpub, wallet.xpub);
      expect(key.derivationPath, wallet.derivationPath);
      expect(
        key.descriptorPath,
        wallet.network.startsWith('bitcoin')
            ? standardSingleSignatureDescriptorPath
            : '',
      );
    }

    await migratedDb.close();
  });

  test('failed v15 migration rolls back and can be retried', () async {
    final schema = await verifier.schemaAt(15);
    final wallet = _wallets.last;
    final oldDb = v15.DatabaseAtV15(schema.newConnection());
    await _insertLegacyWallet(oldDb, wallet, 0);
    await oldDb.customStatement(
      'CREATE TABLE wallet_signers (sentinel TEXT NOT NULL)',
    );
    await oldDb.close();

    final failedDb = SqliteDatabase(schema.newConnection());
    await expectLater(
      failedDb.customSelect('SELECT 1').get(),
      throwsA(anything),
    );
    await failedDb.close();

    final rolledBackDb = v15.DatabaseAtV15(schema.newConnection());
    final columns = await rolledBackDb
        .customSelect("PRAGMA table_info('wallet_metadatas')")
        .get();
    final columnNames = columns.map((row) => row.read<String>('name')).toSet();
    expect(columnNames, containsAll(<String>{'xpub', 'master_fingerprint'}));
    expect(columnNames, isNot(contains('network')));

    final rows = await rolledBackDb.select(rolledBackDb.walletMetadatas).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, wallet.id);
    expect(rows.single.xpub, wallet.xpub);
    expect(rows.single.externalPublicDescriptor, wallet.externalDescriptor);
    expect(rows.single.internalPublicDescriptor, wallet.internalDescriptor);

    final version = await rolledBackDb
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 15);

    await rolledBackDb.customStatement('DROP TABLE wallet_signers');
    await rolledBackDb.close();

    final retryDb = SqliteDatabase(schema.newConnection());
    await verifier.migrateAndValidate(retryDb, 16);
    await retryDb.close();

    final migratedDb = v16.DatabaseAtV16(schema.newConnection());
    final metadataRows = await migratedDb
        .select(migratedDb.walletMetadatas)
        .get();
    final signerRows = await migratedDb.select(migratedDb.walletSigners).get();
    final keyRows = await migratedDb
        .select(migratedDb.walletDescriptorKeys)
        .get();
    expect(metadataRows.single.publicDescriptor, _expectedDescriptor(wallet));
    expect(signerRows.single.walletId, wallet.id);
    expect(keyRows.single.derivationPath, wallet.derivationPath);
    await migratedDb.close();
  });
}

String _expectedDescriptor(_LegacyWallet wallet) {
  if (wallet.network.startsWith('liquid')) return wallet.externalDescriptor;
  return BdkFacade.combinePublicDescriptorPair(
    externalDescriptor: wallet.externalDescriptor,
    internalDescriptor: wallet.internalDescriptor,
    isTestnet: wallet.network == 'bitcoinTestnet',
  );
}

({String external, String internal}) _expandBitcoinDescriptor(
  String descriptor, {
  required bool isTestnet,
}) {
  final multipath = bdk.Descriptor(
    descriptor: descriptor,
    networkKind: isTestnet ? bdk.NetworkKind.test : bdk.NetworkKind.main,
  );
  try {
    final descriptors = multipath.toSingleDescriptors();
    try {
      expect(descriptors, hasLength(2));
      return (
        external: descriptors.first.toString(),
        internal: descriptors.last.toString(),
      );
    } finally {
      for (final descriptor in descriptors) {
        descriptor.dispose();
      }
    }
  } finally {
    multipath.dispose();
  }
}

Future<void> _insertLegacyWallet(
  v15.DatabaseAtV15 db,
  _LegacyWallet wallet,
  int index,
) async {
  await db
      .into(db.walletMetadatas)
      .insert(
        v15.WalletMetadatasCompanion.insert(
          id: wallet.id,
          masterFingerprint: wallet.masterFingerprint,
          xpubFingerprint: wallet.xpubFingerprint,
          isEncryptedVaultTested: index.isEven ? 1 : 0,
          isPhysicalBackupTested: index.isOdd ? 1 : 0,
          latestEncryptedBackup: Value(
            index.isEven ? 1680000000 + index : null,
          ),
          latestPhysicalBackup: Value(index.isOdd ? 1681000000 + index : null),
          xpub: wallet.xpub,
          externalPublicDescriptor: wallet.externalDescriptor,
          internalPublicDescriptor: wallet.internalDescriptor,
          signer: wallet.signer,
          signerDevice: Value(wallet.signerDevice),
          isDefault: index == 0 ? 1 : 0,
          label: Value(index.isEven ? 'wallet-$index' : null),
          syncedAt: Value(
            index.isEven ? '2026-08-0${index + 1}T00:00:00.000Z' : null,
          ),
          birthday: Value(
            index.isOdd ? '2025-08-0${index + 1}T00:00:00.000Z' : null,
          ),
        ),
      );
}
