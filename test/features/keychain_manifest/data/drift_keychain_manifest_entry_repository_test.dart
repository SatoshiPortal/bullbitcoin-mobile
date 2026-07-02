import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_entry.dart';
import 'package:bb_mobile/features/keychain_manifest/data/drift_keychain_manifest_entry_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SqliteDatabase database;
  late DriftKeychainManifestEntryRepository store;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    store = DriftKeychainManifestEntryRepository(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'roundtrips wallet materializations for a generic manifest entry',
    () async {
      final record = _record();

      await store.insertWalletMaterializationRecord(record);

      final byWallet = await store.fetchWalletMaterializationRecordByWalletId(
        record.walletId,
      );

      expect(byWallet!.walletId, record.walletId);
      expect(byWallet.entry.parentFingerprint, record.entry.parentFingerprint);
      expect(
        byWallet.walletMaterialization.childSeedFingerprint,
        record.walletMaterialization.childSeedFingerprint,
      );
    },
  );

  test('enforces wallet id uniqueness', () async {
    await store.insertWalletMaterializationRecord(_record());

    expect(
      () => store.insertWalletMaterializationRecord(
        _record(network: 'liquidMainnet'),
      ),
      throwsA(isA<KeychainManifestDuplicateException>()),
    );
  });

  test('allows same entry and network on another wallet id', () async {
    await store.insertWalletMaterializationRecord(_record());
    await store.insertWalletMaterializationRecord(
      _record(walletId: 'other-wallet'),
    );

    final bindings = await database
        .select(database.keychainManifestWalletBindings)
        .get();
    expect(bindings, hasLength(2));
  });

  test('allows same entry on another wallet network', () async {
    await store.insertWalletMaterializationRecord(_record());
    await store.insertWalletMaterializationRecord(
      _record(walletId: 'lbtc-wallet', network: 'liquidMainnet'),
    );

    final entries = await database
        .select(database.keychainManifestEntries)
        .get();
    final bindings = await database
        .select(database.keychainManifestWalletBindings)
        .get();
    expect(entries, hasLength(1));
    expect(bindings, hasLength(2));
  });

  test('fetches wallet materializations by parent fingerprint', () async {
    await store.insertWalletMaterializationRecord(
      _record(
        walletId: 'z-wallet',
        bip85DerivationPath: "39'/0'/12'/101'",
        bip85Index: 101,
      ),
    );
    await store.insertWalletMaterializationRecord(
      _record(walletId: 'btc-wallet', network: 'bitcoinMainnet'),
    );
    await store.insertWalletMaterializationRecord(
      _record(walletId: 'lbtc-wallet', network: 'liquidMainnet'),
    );
    await store.insertWalletMaterializationRecord(
      _record(walletId: 'other-parent', parentFingerprint: '00112233'),
    );

    final records = await store
        .fetchWalletMaterializationRecordsByParentFingerprint(' FEDCBA98 ');

    // Order is unspecified at the repository boundary; deterministic file
    // ordering is owned by the build usecase.
    expect(
      records.map((record) => record.walletId),
      unorderedEquals(['btc-wallet', 'lbtc-wallet', 'z-wallet']),
    );
    expect(
      records.every((record) => record.entry.parentFingerprint == 'fedcba98'),
      isTrue,
    );
  });
}

KeychainManifestWalletMaterializationRecord _record({
  String walletId = 'btc-wallet',
  String parentFingerprint = 'fedcba98',
  String childSeedFingerprint = '0123abcd',
  String bip85DerivationPath = "39'/0'/12'/100'",
  String network = 'bitcoinMainnet',
  String reservationId = 'btcpay_wallet_seed',
  String entryType = 'walletSeed',
  String ownerFeature = 'btcpay',
  int bip85Application = 39,
  int bip85Index = 100,
  String scriptType = 'bip84',
}) {
  final entry = KeychainManifestEntry(
    parentFingerprint: parentFingerprint,
    bip85DerivationPath: bip85DerivationPath,
    reservationId: reservationId,
    entryType: entryType,
    ownerFeature: ownerFeature,
    bip85Application: bip85Application,
    bip85Index: bip85Index,
    createdAt: 1,
    updatedAt: 1,
  );
  return KeychainManifestWalletMaterializationRecord(
    entry: entry,
    walletMaterialization: KeychainManifestWalletMaterialization(
      walletId: walletId,
      entryId: entry.entryId,
      childSeedFingerprint: childSeedFingerprint,
      network: network,
      scriptType: scriptType,
      createdAt: 1,
      updatedAt: 1,
    ),
  );
}
