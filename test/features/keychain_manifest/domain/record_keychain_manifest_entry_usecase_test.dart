import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_entry_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_request.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/record_keychain_manifest_entry_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _InMemoryKeychainManifestStore store;
  late RecordKeychainManifestEntryUsecase usecase;

  setUp(() {
    store = _InMemoryKeychainManifestStore();
    usecase = RecordKeychainManifestEntryUsecase(repository: store);
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
        const KeychainManifestReservedDerivationRequest(
          reservationId: 'btcpay_wallet_seed',
          parentFingerprint: 'fedcba98',
          derivationPath: "39'/0'/12'/100'",
          materializations: [
            KeychainManifestWalletMaterializationRequest(
              walletId: 'btc-wallet',
              childSeedFingerprint: '0123abcd',
              network: Network.bitcoinMainnet,
              walletPurpose: 'bitcoin',
              scriptType: ScriptType.bip84,
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
        () => usecase.execute(_command(network: Network.liquidMainnet)),
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
      _command(walletId: 'lbtc-wallet', network: Network.liquidMainnet),
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

  test('records when the derived path matches the reservation path', () async {
    await usecase.execute(_command(derivationPath: "39'/0'/12'/100'"));

    expect(store.entries.single.bip85DerivationPath, "39'/0'/12'/100'");
    expect(store.records, hasLength(1));
  });

  test(
    'refuses to record when the derived path does not match the reservation',
    () async {
      await expectLater(
        usecase.execute(_command(derivationPath: "39'/0'/12'/101'")),
        throwsA(isA<KeychainManifestInvalidEntryException>()),
      );

      expect(store.entries, isEmpty);
      expect(store.records, isEmpty);
    },
  );

  test(
    'treats metadata-only differences on an identity-equal record as the same '
    'record, stored row wins',
    () async {
      // Simulates a stored row written by an older app version whose
      // descriptive metadata strings have since been renamed in code. The
      // durable identity (fingerprint + path + wallet binding) is equal, so
      // re-recording must be idempotent instead of a conflict, and the
      // stored row must win because entries are append-only (no update).
      final stored = _record(
        reservationId: 'legacy_reservation_name',
        entryType: 'legacyEntryType',
        ownerFeature: 'legacyOwner',
      );
      store.entries.add(stored.entry);
      store.records.add(stored);

      await expectLater(usecase.execute(_command()), completes);

      expect(store.records, hasLength(1));
      expect(store.entries.single.reservationId, 'legacy_reservation_name');
      expect(store.entries.single.entryType, 'legacyEntryType');
      expect(store.entries.single.ownerFeature, 'legacyOwner');
    },
  );

  test(
    'still conflicts when identity fields differ for the same wallet',
    () async {
      await usecase.execute(_command());

      expect(
        () => usecase.execute(_command(childSeedFingerprint: 'aaaa1111')),
        throwsA(isA<KeychainManifestEntryConflictException>()),
      );
    },
  );

  group('frozen wire values', () {
    // These strings are persisted to the local manifest store and (later in
    // the stack) exported into the manifest file contract. They are FROZEN
    // WIRE VALUES: renaming the source enums or registry ids must not change
    // what is written, or previously recorded rows would stop matching and
    // exported manifests would change meaning. Update these tests only with
    // an explicit, versioned wire-format decision.
    test('frozen wire value: reservation id btcpay_wallet_seed', () async {
      await usecase.execute(_command());

      expect(store.entries.single.reservationId, 'btcpay_wallet_seed');
    });

    test('frozen wire value: entry type walletSeed', () async {
      await usecase.execute(_command());

      expect(store.entries.single.entryType, 'walletSeed');
    });

    test('frozen wire value: owner feature btcpay', () async {
      await usecase.execute(_command());

      expect(store.entries.single.ownerFeature, 'btcpay');
    });

    test('frozen wire value: network names', () {
      expect(Network.bitcoinMainnet.name, 'bitcoinMainnet');
      expect(Network.bitcoinTestnet.name, 'bitcoinTestnet');
      expect(Network.liquidMainnet.name, 'liquidMainnet');
      expect(Network.liquidTestnet.name, 'liquidTestnet');
    });

    test('frozen wire value: script type names', () {
      expect(ScriptType.bip84.name, 'bip84');
      expect(ScriptType.bip49.name, 'bip49');
      expect(ScriptType.bip44.name, 'bip44');
    });

    test('frozen wire value: persisted network and script type', () async {
      await usecase.execute(_command());

      expect(
        store.records.single.walletMaterialization.network,
        'bitcoinMainnet',
      );
      expect(store.records.single.walletMaterialization.scriptType, 'bip84');
    });
  });

  test('keeps inserted batch records if a later record fails', () async {
    store.failOnWalletId = 'lbtc-wallet';

    await expectLater(
      usecase.execute(
        _command(
          extraWalletMaterializations: [
            const KeychainManifestWalletMaterializationRequest(
              walletId: 'lbtc-wallet',
              childSeedFingerprint: '0123abcd',
              network: Network.liquidMainnet,
              walletPurpose: 'liquid',
              scriptType: ScriptType.bip84,
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
          const KeychainManifestWalletMaterializationRequest(
            walletId: 'lbtc-wallet',
            childSeedFingerprint: '0123abcd',
            network: Network.liquidMainnet,
            walletPurpose: 'liquid',
            scriptType: ScriptType.bip84,
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

KeychainManifestReservedDerivationRequest _command({
  String reservationId = 'btcpay_wallet_seed',
  String parentFingerprint = 'fedcba98',
  String derivationPath = "39'/0'/12'/100'",
  String walletId = 'btc-wallet',
  String childSeedFingerprint = '0123abcd',
  Network network = Network.bitcoinMainnet,
  String walletPurpose = 'bitcoin',
  ScriptType scriptType = ScriptType.bip84,
  List<KeychainManifestWalletMaterializationRequest>
      extraWalletMaterializations =
      const [],
}) {
  return KeychainManifestReservedDerivationRequest(
    reservationId: reservationId,
    parentFingerprint: parentFingerprint,
    derivationPath: derivationPath,
    materializations: [
      KeychainManifestWalletMaterializationRequest(
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

class _InMemoryKeychainManifestStore
    implements KeychainManifestEntryRepository {
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
