import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_entry.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_entry_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/build_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_keychain_manifest_entry_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _InMemoryKeychainManifestStore store;
  late KeychainManifestFacade facade;

  setUp(() {
    store = _InMemoryKeychainManifestStore();
    facade = KeychainManifestFacade(
      recordEntry: RecordKeychainManifestEntryUsecase(
        repository: store,
        bip85Registry: const Bip85RegistryFacade(),
      ),
      buildManifestFile: BuildKeychainManifestFileUsecase(repository: store),
    );
  });

  test('rejects unknown reservation ids at the public boundary', () async {
    await expectLater(
      facade.recordReservedDerivation(
        KeychainManifestReservedDerivationRequest(
          reservationId: 'unknown_feature',
          derivationPath: "39'/0'/12'/100'",
          parentFingerprint: 'fedcba98',
          materializations: [_walletMaterialization()],
        ),
      ),
      throwsA(isA<KeychainManifestException>()),
    );
  });

  test('rejects empty materialization lists at the public boundary', () async {
    await expectLater(
      facade.recordReservedDerivation(
        const KeychainManifestReservedDerivationRequest(
          reservationId: 'btcpay_wallet_seed',
          derivationPath: "39'/0'/12'/100'",
          parentFingerprint: 'fedcba98',
          materializations: [],
        ),
      ),
      throwsA(
        isA<KeychainManifestException>().having(
          (error) => error.type,
          'type',
          KeychainManifestExceptionType.invalidEntry,
        ),
      ),
    );
  });

  test('derives reserved path and owner metadata from the registry', () async {
    await facade.recordReservedDerivation(
      KeychainManifestReservedDerivationRequest(
        reservationId: 'btcpay_wallet_seed',
        derivationPath: "39'/0'/12'/100'",
        parentFingerprint: 'fedcba98',
        materializations: [_walletMaterialization()],
      ),
      now: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
    );

    expect(store.entries.single.reservationId, 'btcpay_wallet_seed');
    expect(store.entries.single.ownerFeature, 'btcpay');
    expect(store.entries.single.entryType, 'walletSeed');
    expect(store.entries.single.bip85DerivationPath, "39'/0'/12'/100'");
    expect(store.entries.single.bip85Application, 39);
    expect(store.entries.single.bip85Index, 100);
  });

  test('records additional wallet materializations idempotently', () async {
    await facade.recordReservedDerivation(
      KeychainManifestReservedDerivationRequest(
        reservationId: 'btcpay_wallet_seed',
        derivationPath: "39'/0'/12'/100'",
        parentFingerprint: 'fedcba98',
        materializations: [_walletMaterialization()],
      ),
    );

    await facade.recordReservedDerivation(
      KeychainManifestReservedDerivationRequest(
        reservationId: 'btcpay_wallet_seed',
        derivationPath: "39'/0'/12'/100'",
        parentFingerprint: 'fedcba98',
        materializations: [
          _walletMaterialization(),
          _walletMaterialization(
            walletId: 'lbtc-wallet',
            network: Network.liquidMainnet,
          ),
        ],
      ),
    );

    expect(store.records.map((record) => record.walletId), [
      'btc-wallet',
      'lbtc-wallet',
    ]);
  });

  test('builds manifest file payloads from recorded local inventory', () async {
    await facade.recordReservedDerivation(
      KeychainManifestReservedDerivationRequest(
        reservationId: 'btcpay_wallet_seed',
        derivationPath: "39'/0'/12'/100'",
        parentFingerprint: ' FEDCBA98 ',
        materializations: [
          _walletMaterialization(),
          _walletMaterialization(
            walletId: 'lbtc-wallet',
            network: Network.liquidMainnet,
          ),
        ],
      ),
      now: DateTime.fromMillisecondsSinceEpoch(10000, isUtc: true),
    );

    final payload = await facade.buildManifestFilePayload(
      'fedcba98',
      now: DateTime.fromMillisecondsSinceEpoch(20000, isUtc: true),
    );

    expect(payload.payload, _manifestPayload);
    expect(payload.entryCount, 1);
    expect(payload.materializationCount, 2);
    expect(payload.generatedAt, 20);
    expect(payload.inventoryUpdatedAt, 10);
    expect(payload.isEmpty, isFalse);
  });

  test(
    'requires an explicit caller decision before exporting empty inventory',
    () async {
      await expectLater(
        facade.buildManifestFilePayload('fedcba98'),
        throwsA(
          isA<KeychainManifestException>().having(
            (error) => error.type,
            'type',
            KeychainManifestExceptionType.emptyInventory,
          ),
        ),
      );

      final payload = await facade.buildManifestFilePayload(
        'fedcba98',
        allowEmpty: true,
        now: DateTime.fromMillisecondsSinceEpoch(20000, isUtc: true),
      );

      expect(payload.payload, contains('"inventoryUpdatedAt":0'));
      expect(payload.payload, contains('"entryCount":0'));
      expect(payload.payload, contains('"materializationCount":0'));
      expect(payload.payload, contains('"entries":[]'));
      expect(payload.entryCount, 0);
      expect(payload.materializationCount, 0);
      expect(payload.generatedAt, 20);
      expect(payload.inventoryUpdatedAt, 0);
      expect(payload.isEmpty, isTrue);
    },
  );
}

const _manifestPayload =
    '{"version":1,"parentFingerprint":"fedcba98","generatedAt":20,'
    '"inventoryUpdatedAt":10,"entryCount":1,"materializationCount":2,'
    '"entries":[{"entryId":"fedcba98:39\'/0\'/12\'/100\'",'
    '"bip85DerivationPath":"39\'/0\'/12\'/100\'",'
    '"reservationId":"btcpay_wallet_seed","entryType":"walletSeed",'
    '"ownerFeature":"btcpay","bip85Application":39,"bip85Index":100,'
    '"createdAt":10,"updatedAt":10,"materializations":[{"type":"wallet",'
    '"walletId":"btc-wallet","childSeedFingerprint":"0123abcd",'
    '"network":"bitcoinMainnet","scriptType":"bip84",'
    '"createdAt":10,"updatedAt":10},{"type":"wallet",'
    '"walletId":"lbtc-wallet","childSeedFingerprint":"0123abcd",'
    '"network":"liquidMainnet","scriptType":"bip84",'
    '"createdAt":10,"updatedAt":10}]}]}';

KeychainManifestWalletMaterializationRequest _walletMaterialization({
  String walletId = 'btc-wallet',
  String childSeedFingerprint = '0123abcd',
  Network network = Network.bitcoinMainnet,
  ScriptType scriptType = ScriptType.bip84,
}) {
  return KeychainManifestWalletMaterializationRequest(
    walletId: walletId,
    childSeedFingerprint: childSeedFingerprint,
    network: network,
    scriptType: scriptType,
  );
}

class _InMemoryKeychainManifestStore
    implements KeychainManifestEntryRepository {
  final entries = <KeychainManifestEntry>[];
  final records = <KeychainManifestWalletMaterializationRecord>[];

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
  Future<List<KeychainManifestWalletMaterializationRecord>>
  fetchWalletMaterializationRecordsByParentFingerprint(
    String parentFingerprint,
  ) async {
    return records
        .where((record) => record.entry.parentFingerprint == parentFingerprint)
        .toList(growable: false);
  }

  @override
  Future<void> insertWalletMaterializationRecord(
    KeychainManifestWalletMaterializationRecord record,
  ) async {
    if (await fetchWalletMaterializationRecordByWalletId(record.walletId) !=
        null) {
      throw KeychainManifestDuplicateException('duplicate');
    }
    final existingEntry = entries.cast<KeychainManifestEntry?>().firstWhere(
      (entry) => entry!.entryId == record.entry.entryId,
      orElse: () => null,
    );
    if (existingEntry == null) {
      entries.add(record.entry);
    } else if (!existingEntry.sameRecordAs(record.entry)) {
      throw KeychainManifestDuplicateException('entry duplicate');
    }
    records.add(record);
  }
}
