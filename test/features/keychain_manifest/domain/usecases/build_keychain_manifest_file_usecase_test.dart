import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_entry_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/build_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _InMemoryKeychainManifestStore store;
  late BuildKeychainManifestFileUsecase usecase;

  setUp(() {
    store = _InMemoryKeychainManifestStore();
    usecase = BuildKeychainManifestFileUsecase(
      repository: store,
      registry: const Bip85RegistryFacade(),
    );
  });

  test('builds an empty manifest file for a parent fingerprint', () async {
    final manifestFile = await usecase.execute(
      'fedcba98',
      now: DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true),
    );

    expect(manifestFile.parentFingerprint, 'fedcba98');
    expect(manifestFile.generatedAt, 2);
    expect(manifestFile.inventoryUpdatedAt, 0);
    expect(manifestFile.entries, isEmpty);
  });

  test('groups wallet materializations under their BIP85 entry', () async {
    store.records.addAll([
      _record(walletId: 'lbtc-wallet', network: 'liquidMainnet', updatedAt: 11),
      _record(walletId: 'btc-wallet', network: 'bitcoinMainnet', updatedAt: 10),
    ]);

    final manifestFile = await usecase.execute(
      'fedcba98',
      now: DateTime.fromMillisecondsSinceEpoch(20000, isUtc: true),
    );

    expect(manifestFile.generatedAt, 20);
    expect(manifestFile.inventoryUpdatedAt, 12);
    expect(manifestFile.entries, hasLength(1));
    expect(manifestFile.entries.single.bip85DerivationPath, "39'/0'/12'/100'");
    expect(
      manifestFile.entries.single.materializations.map(
        (materialization) => materialization.walletId,
      ),
      ['btc-wallet', 'lbtc-wallet'],
    );
  });

  test('maps invalid fingerprint input to a keychain manifest error', () async {
    await expectLater(
      usecase.execute('invalid'),
      throwsA(
        isA<KeychainManifestInvalidEntryException>().having(
          (error) => error.type,
          'type',
          KeychainManifestExceptionType.invalidEntry,
        ),
      ),
    );
  });

  test('excludes unsupported wallet reservations from v1 export', () async {
    store.records.addAll([
      _record(walletId: 'btc-wallet', network: 'bitcoinMainnet', updatedAt: 10),
      _record(
        reservationId: 'lightning_address_wallet_seed',
        ownerFeature: 'lightningAddress',
        bip85DerivationPath: "39'/0'/12'/101'",
        bip85Index: 101,
        walletId: 'lightning-address-wallet',
        network: 'liquidMainnet',
        updatedAt: 13,
      ),
    ]);

    final manifestFile = await usecase.execute(
      'fedcba98',
      now: DateTime.fromMillisecondsSinceEpoch(20000, isUtc: true),
    );

    expect(manifestFile.entries, hasLength(1));
    expect(manifestFile.entries.single.reservationId, 'btcpay_wallet_seed');
    expect(
      manifestFile.entries.single.materializations.single.walletId,
      'btc-wallet',
    );
    expect(manifestFile.inventoryUpdatedAt, 12);
  });
}

KeychainManifestWalletMaterializationRecord _record({
  String walletId = 'btc-wallet',
  String parentFingerprint = 'fedcba98',
  String childSeedFingerprint = '0123abcd',
  String reservationId = 'btcpay_wallet_seed',
  String entryType = 'walletSeed',
  String ownerFeature = 'btcpay',
  String bip85DerivationPath = "39'/0'/12'/100'",
  int bip85Application = 39,
  int bip85Index = 100,
  String network = 'bitcoinMainnet',
  int updatedAt = 10,
}) {
  final entry = KeychainManifestEntry(
    parentFingerprint: parentFingerprint,
    bip85DerivationPath: bip85DerivationPath,
    reservationId: reservationId,
    entryType: entryType,
    ownerFeature: ownerFeature,
    bip85Application: bip85Application,
    bip85Index: bip85Index,
    createdAt: 10,
    updatedAt: 12,
  );
  return KeychainManifestWalletMaterializationRecord(
    entry: entry,
    walletMaterialization: KeychainManifestWalletMaterialization(
      walletId: walletId,
      entryId: entry.entryId,
      childSeedFingerprint: childSeedFingerprint,
      network: network,
      scriptType: 'bip84',
      createdAt: updatedAt,
      updatedAt: updatedAt,
    ),
  );
}

class _InMemoryKeychainManifestStore
    implements KeychainManifestEntryRepository {
  final records = <KeychainManifestWalletMaterializationRecord>[];

  @override
  Future<List<KeychainManifestWalletMaterializationRecord>>
  fetchWalletMaterializationRecordsByParentFingerprint(
    String parentFingerprint,
  ) async {
    return records
        .where((record) => record.entry.parentFingerprint == parentFingerprint)
        .toList(growable: false);
  }

  @override
  Future<void> insertWalletMaterializationRecords(
    List<KeychainManifestWalletMaterializationRecord> records,
  ) async {
    this.records.addAll(records);
  }
}
