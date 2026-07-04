import 'dart:convert';

import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_entry.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_entry_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/build_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
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
      buildManifestFile: BuildKeychainManifestFileUsecase(
        repository: store,
        registry: const Bip85RegistryFacade(),
      ),
      parseManifestFile: const ParseKeychainManifestFileUsecase(
        codec: KeychainManifestFileCodec(),
        bip85Registry: Bip85RegistryFacade(),
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

  // Decision [F] v1 format freeze (schema-lock leg). The byte-exact golden above
  // freezes the serialized value; this freezes the SHAPE: the exact key set at
  // each level. Adding, renaming, retyping, or removing a field flips this red
  // with a message telling the author the frozen v1 contract requires a human
  // decision (additive-only evolution). Companion decode/forward-compat checks
  // land at pr05 where the decoder exists (R2-F1).
  test('v1 manifest key sets are frozen at every level', () async {
    await facade.recordReservedDerivation(
      KeychainManifestReservedDerivationRequest(
        reservationId: 'btcpay_wallet_seed',
        derivationPath: "39'/0'/12'/100'",
        parentFingerprint: 'fedcba98',
        materializations: [_walletMaterialization()],
      ),
      now: DateTime.fromMillisecondsSinceEpoch(10000, isUtc: true),
    );
    final payload = await facade.buildManifestFilePayload(
      'fedcba98',
      now: DateTime.fromMillisecondsSinceEpoch(20000, isUtc: true),
    );

    final decoded = jsonDecode(payload.payload) as Map<String, Object?>;
    expect(
      decoded.keys.toSet(),
      {
        'version',
        'parentFingerprint',
        'generatedAt',
        'inventoryUpdatedAt',
        'entryCount',
        'materializationCount',
        'entries',
      },
      reason:
          'Frozen v1 manifest file-level key set changed. Do not rename, remove, '
          'or retype a field; add a new golden vector and update the frozen '
          'contract deliberately (decision [F]).',
    );

    final entry = (decoded['entries']! as List).single as Map<String, Object?>;
    expect(
      entry.keys.toSet(),
      {
        'entryId',
        'bip85DerivationPath',
        'reservationId',
        'entryType',
        'ownerFeature',
        'bip85Application',
        'bip85Index',
        'createdAt',
        'updatedAt',
        'materializations',
      },
      reason: 'Frozen v1 manifest entry-level key set changed (decision [F]).',
    );

    final materialization =
        (entry['materializations']! as List).single as Map<String, Object?>;
    expect(
      materialization.keys.toSet(),
      {
        'type',
        'walletId',
        'childSeedFingerprint',
        'network',
        'scriptType',
        'createdAt',
        'updatedAt',
      },
      reason:
          'Frozen v1 manifest materialization-level key set changed '
          '(decision [F]).',
    );
  });

  test('parses manifest file payloads into import plans', () {
    final plan = facade.parseManifestFilePayload(
      _manifestPayload,
      expectedParentFingerprint: ' FEDCBA98 ',
    );

    expect(plan.parentFingerprint, 'fedcba98');
    expect(plan.entries, hasLength(1));
    expect(plan.entries.single.reservationId, 'btcpay_wallet_seed');
    expect(plan.walletMaterializations, hasLength(2));
    expect(plan.walletMaterializations.first.walletId, 'btc-wallet');
    expect(plan.walletMaterializations.last.walletId, 'lbtc-wallet');
  });

  test('exposes the explicit empty-import decision to callers', () {
    const emptyPayload =
        '{"version":1,"parentFingerprint":"fedcba98","generatedAt":20,'
        '"inventoryUpdatedAt":0,"entryCount":0,"materializationCount":0,'
        '"entries":[]}';

    expect(
      () => facade.parseManifestFilePayload(
        emptyPayload,
        expectedParentFingerprint: 'fedcba98',
      ),
      throwsA(
        isA<KeychainManifestException>().having(
          (error) => error.type,
          'type',
          KeychainManifestExceptionType.emptyInventory,
        ),
      ),
    );

    final plan = facade.parseManifestFilePayload(
      emptyPayload,
      expectedParentFingerprint: 'fedcba98',
      allowEmpty: true,
    );

    expect(plan.entries, isEmpty);
  });

  test('surfaces a newer-version manifest file as unsupported, not missing', () {
    // KC-2: a well-formed backup written by a newer app version must reach the
    // consumer as the unsupported-version type ("update the app"), never as a
    // generic invalid file or a "no backup found" signal.
    final payload = _manifestPayload.replaceFirst('"version":1', '"version":2');

    expect(
      () => facade.parseManifestFilePayload(
        payload,
        expectedParentFingerprint: 'fedcba98',
      ),
      throwsA(
        isA<KeychainManifestException>().having(
          (error) => error.type,
          'type',
          KeychainManifestExceptionType.unsupportedFileVersion,
        ),
      ),
    );
  });

  test(
    'the frozen v1 format round-trips every exportable Get Paid seed',
    () async {
      // R2-F1b completeness ([F]): record BTCPay(100) + Lightning Address(101) +
      // Payment Page(102), export to the frozen format, and parse it back - the
      // import plan must carry all three, proving the frozen v1 format represents
      // the whole Get Paid family. Recovery/materialization of 101/102 is PR23;
      // this proves export + parse coverage only (ruling A/B).
      await facade.recordReservedDerivation(
        KeychainManifestReservedDerivationRequest(
          reservationId: 'btcpay_wallet_seed',
          derivationPath: "39'/0'/12'/100'",
          parentFingerprint: 'fedcba98',
          materializations: [_walletMaterialization()],
        ),
        now: DateTime.fromMillisecondsSinceEpoch(10000, isUtc: true),
      );
      await facade.recordReservedDerivation(
        KeychainManifestReservedDerivationRequest(
          reservationId: 'lightning_address_wallet_seed',
          derivationPath: "39'/0'/12'/101'",
          parentFingerprint: 'fedcba98',
          materializations: [
            _walletMaterialization(
              walletId: 'ln-wallet',
              network: Network.liquidMainnet,
            ),
          ],
        ),
        now: DateTime.fromMillisecondsSinceEpoch(11000, isUtc: true),
      );
      await facade.recordReservedDerivation(
        KeychainManifestReservedDerivationRequest(
          reservationId: 'payment_page_wallet_seed',
          derivationPath: "39'/0'/12'/102'",
          parentFingerprint: 'fedcba98',
          materializations: [
            _walletMaterialization(
              walletId: 'page-wallet',
              network: Network.liquidMainnet,
            ),
          ],
        ),
        now: DateTime.fromMillisecondsSinceEpoch(12000, isUtc: true),
      );

      final payload = await facade.buildManifestFilePayload(
        'fedcba98',
        now: DateTime.fromMillisecondsSinceEpoch(20000, isUtc: true),
      );
      final plan = facade.parseManifestFilePayload(
        payload.payload,
        expectedParentFingerprint: 'fedcba98',
      );

      expect(payload.entryCount, 3);
      expect(plan.entries.map((entry) => entry.reservationId), [
        'btcpay_wallet_seed',
        'lightning_address_wallet_seed',
        'payment_page_wallet_seed',
      ]);
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
    for (final record in records) {
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
