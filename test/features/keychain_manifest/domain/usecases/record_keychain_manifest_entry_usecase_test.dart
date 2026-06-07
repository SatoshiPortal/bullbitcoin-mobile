import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_entry_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_request.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_keychain_manifest_entry_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_entry.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _InMemoryKeychainManifestStore store;
  late RecordKeychainManifestEntryUsecase usecase;

  setUp(() {
    store = _InMemoryKeychainManifestStore();
    usecase = RecordKeychainManifestEntryUsecase(
      repository: store,
      bip85Registry: const Bip85RegistryFacade(),
    );
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

  test('records Lightning Address reserved wallet metadata', () async {
    await usecase.execute(
      _command(
        reservationId: 'lightning_address_wallet_seed',
        derivationPath: "39'/0'/12'/101'",
        walletId: 'lightning-address-wallet',
        network: Network.liquidMainnet,
      ),
    );

    expect(store.entries.single.reservationId, 'lightning_address_wallet_seed');
    expect(store.entries.single.ownerFeature, 'lightningAddress');
    expect(store.entries.single.bip85DerivationPath, "39'/0'/12'/101'");
    expect(store.entries.single.bip85Index, 101);
  });

  test('records Payment Page reserved wallet metadata', () async {
    await usecase.execute(
      _command(
        reservationId: 'payment_page_wallet_seed',
        derivationPath: "39'/0'/12'/102'",
        walletId: 'payment-page-wallet',
        network: Network.liquidMainnet,
      ),
    );

    expect(store.entries.single.reservationId, 'payment_page_wallet_seed');
    expect(store.entries.single.ownerFeature, 'paymentPage');
    expect(store.entries.single.bip85DerivationPath, "39'/0'/12'/102'");
    expect(store.entries.single.bip85Index, 102);
  });

  test('rejects key reservations for wallet materializations', () async {
    await expectLater(
      usecase.execute(
        _command(
          reservationId: 'nostr_wallet_manifest_key',
          derivationPath: "9000'/1'/1'",
        ),
      ),
      throwsA(isA<KeychainManifestReservationMismatchException>()),
    );

    expect(store.entries, isEmpty);
    expect(store.records, isEmpty);
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
    // These strings are persisted to the local manifest store and exported
    // into the v1 manifest file contract. They are FROZEN WIRE VALUES:
    // renaming the source enums or registry ids must not change what is
    // written, or previously recorded rows would stop matching and exported
    // manifests would change meaning. The allowed-values table lives in
    // keychain_manifest_architecture.md. Update these tests only with an
    // explicit, versioned wire-format decision.
    test('frozen wire value: reservation id btcpay_wallet_seed', () async {
      await usecase.execute(_command());

      expect(store.entries.single.reservationId, 'btcpay_wallet_seed');
    });

    test('frozen wire value: registry reservation ids', () {
      expect(
        const Bip85RegistryFacade().reservations.map(
          (reservation) => reservation.id,
        ),
        [
          'btcpay_wallet_seed',
          'lightning_address_wallet_seed',
          'payment_page_wallet_seed',
          'nostr_wallet_manifest_key',
          'nostr_bullnym_server_auth_key',
          'nostr_nip05_public_nym_verification_key',
        ],
      );
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

    test('frozen wire value: BIP85 reservation owner names', () {
      expect(Bip85ReservationOwner.values, [
        Bip85ReservationOwner.btcpay,
        Bip85ReservationOwner.lightningAddress,
        Bip85ReservationOwner.paymentPage,
        Bip85ReservationOwner.nostr,
      ]);
      expect(Bip85ReservationOwner.btcpay.name, 'btcpay');
      expect(Bip85ReservationOwner.lightningAddress.name, 'lightningAddress');
      expect(Bip85ReservationOwner.paymentPage.name, 'paymentPage');
      expect(Bip85ReservationOwner.nostr.name, 'nostr');
    });

    test('frozen wire value: BIP85 reservation purpose names', () {
      expect(Bip85ReservationPurpose.values, [
        Bip85ReservationPurpose.walletSeed,
        Bip85ReservationPurpose.nonWalletNostrKey,
      ]);
      expect(Bip85ReservationPurpose.walletSeed.name, 'walletSeed');
      expect(
        Bip85ReservationPurpose.nonWalletNostrKey.name,
        'nonWalletNostrKey',
      );
    });

    test('frozen wire value: wallet materialization type constant', () {
      expect(KeychainManifestFileWalletMaterialization.type, 'wallet');
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

  test('does not keep batch records if a later record fails', () async {
    store.failOnWalletId = 'lbtc-wallet';

    await expectLater(
      usecase.execute(
        _command(
          extraWalletMaterializations: [
            const KeychainManifestWalletMaterializationRequest(
              walletId: 'lbtc-wallet',
              childSeedFingerprint: '0123abcd',
              network: Network.liquidMainnet,
              scriptType: ScriptType.bip84,
            ),
          ],
        ),
      ),
      throwsA(isA<StateError>()),
    );

    expect(store.records, isEmpty);
    expect(store.entries, isEmpty);

    store.failOnWalletId = null;
    await usecase.execute(
      _command(
        extraWalletMaterializations: [
          const KeychainManifestWalletMaterializationRequest(
            walletId: 'lbtc-wallet',
            childSeedFingerprint: '0123abcd',
            network: Network.liquidMainnet,
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

  test(
    'treats duplicate identical rows after precheck as idempotent',
    () async {
      store.insertIdenticalRowsBeforeBatch = true;

      await usecase.execute(_command());

      expect(store.records.map((record) => record.walletId), ['btc-wallet']);
      expect(store.entries, hasLength(1));
    },
  );
}

KeychainManifestReservedDerivationRequest _command({
  String reservationId = 'btcpay_wallet_seed',
  String parentFingerprint = 'fedcba98',
  String derivationPath = "39'/0'/12'/100'",
  String walletId = 'btc-wallet',
  String childSeedFingerprint = '0123abcd',
  Network network = Network.bitcoinMainnet,
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
  bool insertIdenticalRowsBeforeBatch = false;

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
    final nextEntries = [...entries];
    final nextRecords = [...this.records];
    if (insertIdenticalRowsBeforeBatch) {
      for (final record in records) {
        if (!nextRecords.any((stored) => stored.walletId == record.walletId)) {
          nextRecords.add(record);
          if (!nextEntries.any(
            (entry) => entry.entryId == record.entry.entryId,
          )) {
            nextEntries.add(record.entry);
          }
        }
      }
      insertIdenticalRowsBeforeBatch = false;
    }
    for (final record in records) {
      if (record.walletId == failOnWalletId) {
        throw StateError('insert failed');
      }
      final existingRecord = nextRecords
          .cast<KeychainManifestWalletMaterializationRecord?>()
          .firstWhere(
            (stored) => stored!.walletId == record.walletId,
            orElse: () => null,
          );
      if (existingRecord != null) {
        if (existingRecord.sameRecordAs(record)) continue;
        throw KeychainManifestEntryConflictException('duplicate');
      }
      final existingEntry = nextEntries
          .cast<KeychainManifestEntry?>()
          .firstWhere(
            (entry) => entry!.entryId == record.entry.entryId,
            orElse: () => null,
          );
      if (existingEntry == null) {
        nextEntries.add(record.entry);
      } else if (!existingEntry.sameRecordAs(record.entry)) {
        throw KeychainManifestDuplicateException('entry duplicate');
      }
      nextRecords.add(record);
    }
    entries
      ..clear()
      ..addAll(nextEntries);
    this.records
      ..clear()
      ..addAll(nextRecords);
  }
}
