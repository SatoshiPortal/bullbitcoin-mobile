import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_entry_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/build_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _InMemoryKeychainManifestStore store;
  late BuildKeychainManifestFileUsecase usecase;

  setUp(() {
    store = _InMemoryKeychainManifestStore();
    usecase = BuildKeychainManifestFileUsecase(repository: store);
  });

  test('builds an empty manifest file for a parent fingerprint', () async {
    final manifestFile = await usecase.execute(
      const BuildKeychainManifestFileCommand(parentFingerprint: 'fedcba98'),
      now: DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true),
    );

    expect(manifestFile.parentFingerprint, 'fedcba98');
    expect(manifestFile.generatedAt, 2);
    expect(manifestFile.updatedAt, 2);
    expect(manifestFile.entries, isEmpty);
  });

  test('groups wallet materializations under their BIP85 entry', () async {
    store.records.addAll([
      _record(walletId: 'lbtc-wallet', network: 'liquidMainnet', updatedAt: 11),
      _record(walletId: 'btc-wallet', network: 'bitcoinMainnet', updatedAt: 10),
    ]);

    final manifestFile = await usecase.execute(
      const BuildKeychainManifestFileCommand(parentFingerprint: 'fedcba98'),
      now: DateTime.fromMillisecondsSinceEpoch(20000, isUtc: true),
    );

    expect(manifestFile.generatedAt, 20);
    expect(manifestFile.updatedAt, 12);
    expect(manifestFile.entries, hasLength(1));
    expect(manifestFile.entries.single.bip85DerivationPath, "39'/0'/12'/100'");
    expect(
      manifestFile.entries.single.materializations.map(
        (materialization) => materialization.walletId,
      ),
      ['btc-wallet', 'lbtc-wallet'],
    );
  });

  test('maps invalid file input to a keychain manifest error', () async {
    await expectLater(
      usecase.execute(
        const BuildKeychainManifestFileCommand(parentFingerprint: 'invalid'),
      ),
      throwsA(
        isA<KeychainManifestEntryConflictException>().having(
          (error) => error.cause,
          'cause',
          isNotNull,
        ),
      ),
    );
  });
}

KeychainManifestWalletMaterializationRecord _record({
  String walletId = 'btc-wallet',
  String parentFingerprint = 'fedcba98',
  String childSeedFingerprint = '0123abcd',
  String bip85DerivationPath = "39'/0'/12'/100'",
  String network = 'bitcoinMainnet',
  int updatedAt = 10,
}) {
  final entry = KeychainManifestEntry(
    parentFingerprint: parentFingerprint,
    bip85DerivationPath: bip85DerivationPath,
    reservationId: 'btcpay_wallet_seed',
    entryType: 'walletSeed',
    ownerFeature: 'btcpay',
    bip85Application: 39,
    bip85Index: 100,
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
  Future<KeychainManifestWalletMaterializationRecord?>
  fetchWalletMaterializationRecordByWalletId(String walletId) async {
    return records
        .cast<KeychainManifestWalletMaterializationRecord?>()
        .firstWhere(
          (record) => record!.walletId == walletId,
          orElse: () => null,
        );
  }

  @override
  Future<void> insertWalletMaterializationRecord(
    KeychainManifestWalletMaterializationRecord record,
  ) async {
    records.add(record);
  }
}
