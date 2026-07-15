import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_entry_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/record_keychain_manifest_entry_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_entry.dart';
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
}

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
