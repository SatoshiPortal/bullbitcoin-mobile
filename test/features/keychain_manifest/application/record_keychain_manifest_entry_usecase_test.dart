import 'package:bb_mobile/features/keychain_manifest/application/application_errors.dart';
import 'package:bb_mobile/features/keychain_manifest/application/ports/keychain_manifest_entry_store.dart';
import 'package:bb_mobile/features/keychain_manifest/application/usecases/record_keychain_manifest_entry_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/domain_errors.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _InMemoryKeychainManifestStore store;
  late RecordKeychainManifestEntryUsecase usecase;

  setUp(() {
    store = _InMemoryKeychainManifestStore();
    usecase = RecordKeychainManifestEntryUsecase(store: store);
  });

  test('normalizes fingerprints and registry-relative BIP85 paths', () {
    final record = _record(
      parentFingerprint: ' FEDCBA98 ',
      childSeedFingerprint: ' 0123ABCD ',
      bip85DerivationPath: "39'/0'/12'/00100'",
    );

    expect(record.entry.parentFingerprint, 'fedcba98');
    expect(record.walletMaterialization.childSeedFingerprint, '0123abcd');
    expect(record.entry.bip85DerivationPath, "39'/0'/12'/100'");
  });

  test('rejects invalid fingerprints and malformed BIP85 paths', () {
    expect(
      () => _record(parentFingerprint: 'not-hex'),
      throwsA(isA<KeychainManifestInvalidEntryException>()),
    );
    expect(
      () => _record(bip85DerivationPath: "39/0'/12'/100'"),
      throwsA(isA<KeychainManifestInvalidEntryException>()),
    );
  });

  test('rejects explicit entry ids that do not match entry identity', () {
    expect(
      () => _record(entryId: "fedcba98:39'/0'/12'/101'"),
      throwsA(isA<KeychainManifestInvalidEntryException>()),
    );
  });

  test(
    'records reserved derivation commands with registry-owned metadata',
    () async {
      await usecase.execute(
        const RecordReservedKeychainDerivationCommand(
          reservationId: 'btcpay_wallet_seed',
          parentFingerprint: 'fedcba98',
          walletMaterializations: [
            RecordKeychainManifestWalletMaterializationCommand(
              walletId: 'btc-wallet',
              childSeedFingerprint: '0123abcd',
              network: 'bitcoinMainnet',
              walletPurpose: 'bitcoin',
              scriptType: 'bip84',
            ),
          ],
        ),
        now: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      );

      expect(store.entries.single.reservationId, 'btcpay_wallet_seed');
      expect(store.entries.single.entryType, 'walletSeed');
      expect(store.entries.single.ownerFeature, 'btcpay');
      expect(store.entries.single.bip85DerivationPath, "39'/0'/12'/100'");
      expect(store.entries.single.bip85Index, 100);
    },
  );

  test('records exact duplicates idempotently', () async {
    await usecase.execute(_command());
    await usecase.execute(_command());

    expect(store.records, hasLength(1));
  });

  test(
    'rejects the same wallet id with a different wallet materialization',
    () async {
      await usecase.execute(_command());

      expect(
        () => usecase.execute(_command(network: 'liquidMainnet')),
        throwsA(isA<KeychainManifestEntryConflictException>()),
      );
    },
  );

  test('allows the same BIP85 entry and network for another wallet', () async {
    await usecase.execute(_command());

    expect(
      () => usecase.execute(_command(walletId: 'other-wallet')),
      returnsNormally,
    );
  });

  test('allows the same BIP85 entry on a different wallet network', () async {
    await usecase.execute(_command());
    await usecase.execute(
      _command(walletId: 'lbtc-wallet', network: 'liquidMainnet'),
    );

    expect(store.entries, hasLength(1));
    expect(store.records, hasLength(2));
  });

  test('rejects entries that do not match the reservation', () async {
    expect(
      () => usecase.execute(_command(reservationId: 'unknown')),
      throwsA(isA<KeychainManifestReservationMismatchException>()),
    );
  });

  test('keeps inserted batch records if a later record fails', () async {
    store.failOnWalletId = 'lbtc-wallet';

    await expectLater(
      usecase.execute(
        _command(
          extraWalletMaterializations: [
            const RecordKeychainManifestWalletMaterializationCommand(
              walletId: 'lbtc-wallet',
              childSeedFingerprint: '0123abcd',
              network: 'liquidMainnet',
              walletPurpose: 'liquid',
              scriptType: 'bip84',
            ),
          ],
        ),
      ),
      throwsA(isA<StateError>()),
    );

    expect(store.records.map((record) => record.walletId), ['btc-wallet']);
    expect(store.entries, hasLength(1));

    store.failOnWalletId = null;
    await usecase.execute(
      _command(
        extraWalletMaterializations: [
          const RecordKeychainManifestWalletMaterializationCommand(
            walletId: 'lbtc-wallet',
            childSeedFingerprint: '0123abcd',
            network: 'liquidMainnet',
            walletPurpose: 'liquid',
            scriptType: 'bip84',
          ),
        ],
      ),
    );

    expect(store.records.map((record) => record.walletId), [
      'btc-wallet',
      'lbtc-wallet',
    ]);
    expect(store.entries, hasLength(1));
  });
}

RecordReservedKeychainDerivationCommand _command({
  String reservationId = 'btcpay_wallet_seed',
  String parentFingerprint = 'fedcba98',
  String walletId = 'btc-wallet',
  String childSeedFingerprint = '0123abcd',
  String network = 'bitcoinMainnet',
  String walletPurpose = 'bitcoin',
  String scriptType = 'bip84',
  List<RecordKeychainManifestWalletMaterializationCommand>
      extraWalletMaterializations =
      const [],
}) {
  return RecordReservedKeychainDerivationCommand(
    reservationId: reservationId,
    parentFingerprint: parentFingerprint,
    walletMaterializations: [
      RecordKeychainManifestWalletMaterializationCommand(
        walletId: walletId,
        childSeedFingerprint: childSeedFingerprint,
        network: network,
        walletPurpose: walletPurpose,
        scriptType: scriptType,
      ),
      ...extraWalletMaterializations,
    ],
  );
}

KeychainManifestWalletMaterializationRecord _record({
  String? entryId,
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
  String walletPurpose = 'bitcoin',
  String scriptType = 'bip84',
}) {
  final entry = KeychainManifestEntry(
    entryId: entryId,
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
      walletPurpose: walletPurpose,
      scriptType: scriptType,
      createdAt: 1,
      updatedAt: 1,
    ),
  );
}

class _InMemoryKeychainManifestStore implements KeychainManifestEntryStore {
  final entries = <KeychainManifestEntry>[];
  final records = <KeychainManifestWalletMaterializationRecord>[];
  String? failOnWalletId;

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
    if (record.walletId == failOnWalletId) {
      throw StateError('insert failed');
    }
    if (await fetchWalletMaterializationRecordByWalletId(record.walletId) !=
        null) {
      throw const KeychainManifestDuplicateException('duplicate');
    }
    final existingEntry = entries.cast<KeychainManifestEntry?>().firstWhere(
      (entry) => entry!.entryId == record.entry.entryId,
      orElse: () => null,
    );
    if (existingEntry == null) {
      entries.add(record.entry);
    } else if (!existingEntry.sameRecordAs(record.entry)) {
      throw const KeychainManifestDuplicateException('entry duplicate');
    }
    records.add(record);
  }
}
