import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = KeychainManifestFileCodec();
  const usecase = ParseKeychainManifestFileUsecase(
    codec: codec,
    bip85Registry: Bip85RegistryFacade(),
  );

  test('validates registered reservation metadata', () {
    final plan = usecase.execute(
      _manifestPayload,
      expectedParentFingerprint: 'fedcba98',
    );

    expect(plan.parentFingerprint, 'fedcba98');
    expect(plan.entries.single.reservationId, 'btcpay_wallet_seed');
    expect(plan.entries.single.bip85DerivationPath, "39'/0'/12'/100'");
    expect(plan.walletMaterializations, hasLength(2));
  });

  test('normalizes the expected parent fingerprint before comparing', () {
    final plan = usecase.execute(
      _manifestPayload,
      expectedParentFingerprint: ' FEDCBA98 ',
    );

    expect(plan.parentFingerprint, 'fedcba98');
  });

  test('refuses manifest files for another parent fingerprint', () {
    expect(
      () => usecase.execute(
        _manifestPayload,
        expectedParentFingerprint: '0123abcd',
      ),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestFileParseFailureReason.wrongParentFingerprint,
        ),
      ),
    );
  });

  test('requires an explicit caller decision before importing empty files', () {
    expect(
      () => usecase.execute(
        _emptyManifestPayload,
        expectedParentFingerprint: 'fedcba98',
      ),
      throwsA(
        isA<KeychainManifestEmptyInventoryException>().having(
          (error) => error.type,
          'type',
          KeychainManifestExceptionType.emptyInventory,
        ),
      ),
    );

    final plan = usecase.execute(
      _emptyManifestPayload,
      expectedParentFingerprint: 'fedcba98',
      allowEmpty: true,
    );

    expect(plan.parentFingerprint, 'fedcba98');
    expect(plan.entries, isEmpty);
    expect(plan.walletMaterializations, isEmpty);
  });

  test('rejects unknown reservations', () {
    final payload = _manifestPayload.replaceFirst(
      'btcpay_wallet_seed',
      'unknown_wallet_seed',
    );

    expect(
      () => usecase.execute(payload, expectedParentFingerprint: 'fedcba98'),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestFileParseFailureReason.unknownReservation,
        ),
      ),
    );
  });

  test('rejects reservation path mismatches', () {
    // A self-consistent entry (path, entry id, and index agree) pointing at
    // a path the reservation never reserved.
    final payload = _manifestPayload
        .replaceAll("39'/0'/12'/100'", "39'/0'/12'/77'")
        .replaceFirst('"bip85Index":100', '"bip85Index":77');

    expect(
      () => usecase.execute(payload, expectedParentFingerprint: 'fedcba98'),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestFileParseFailureReason.invalidMetadata,
        ),
      ),
    );
  });

  test('rejects reservation metadata mismatches', () {
    final payload = _manifestPayload.replaceFirst(
      '"ownerFeature":"btcpay"',
      '"ownerFeature":"other_feature"',
    );

    expect(
      () => usecase.execute(payload, expectedParentFingerprint: 'fedcba98'),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestFileParseFailureReason.invalidMetadata,
        ),
      ),
    );
  });

  test('rejects payloads larger than the size bound', () {
    final payload = _manifestPayload.padRight(
      KeychainManifestFileCodec.maxPayloadSizeBytes + 1,
    );

    expect(
      () => codec.decode(payload),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestFileParseFailureReason.malformedFile,
        ),
      ),
    );
  });

  test('rejects entries with too many materializations', () {
    final extras = StringBuffer();
    for (var i = 0; i < 8; i++) {
      extras.write(
        '{"type":"wallet","walletId":"wallet-$i",'
        '"childSeedFingerprint":"0123abcd","network":"bitcoinTestnet",'
        '"scriptType":"bip84","createdAt":10,"updatedAt":10},',
      );
    }
    final payload = _manifestPayload.replaceFirst(
      '"materializations":[',
      '"materializations":[$extras',
    );

    expect(
      () => codec.decode(payload),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestFileParseFailureReason.invalidMetadata,
        ),
      ),
    );
  });

  test('rejects oversized string fields', () {
    final oversized =
        'a' * (KeychainManifestFileCodec.maxStringFieldLength + 1);
    final payload = _manifestPayload.replaceFirst(
      '"walletId":"btc-wallet"',
      '"walletId":"$oversized"',
    );

    expect(
      () => codec.decode(payload),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestFileParseFailureReason.malformedFile,
        ),
      ),
    );
  });

  test('rejects more entries than the registry reserves', () {
    // Pinned to the registry size: every valid entry maps to a distinct
    // reservation, so a file carrying more entries than the registry holds
    // (currently ten) can never validate and is bounded before per-entry
    // validation runs.
    final reservationCount = const Bip85RegistryFacade().reservations.length;
    expect(reservationCount, 10);
    final extraEntries = StringBuffer();
    for (var i = 0; i < reservationCount; i++) {
      final index = 200 + i;
      final path = "39'/0'/12'/$index'";
      extraEntries.write(
        ',{"entryId":"fedcba98:$path",'
        '"bip85DerivationPath":"$path",'
        '"reservationId":"btcpay_wallet_seed","entryType":"walletSeed",'
        '"ownerFeature":"btcpay","bip85Application":39,"bip85Index":$index,'
        '"createdAt":10,"updatedAt":12,"materializations":[{"type":"wallet",'
        '"walletId":"extra-wallet-$i","childSeedFingerprint":"0123abcd",'
        '"network":"bitcoinMainnet",'
        '"scriptType":"bip84","createdAt":10,"updatedAt":10}]}',
      );
    }
    final payload = _manifestPayload
        .replaceFirst(']}]}', ']}$extraEntries]}')
        .replaceFirst('"entryCount":1', '"entryCount":${1 + reservationCount}')
        .replaceFirst(
          '"materializationCount":2',
          '"materializationCount":${2 + reservationCount}',
        );

    expect(
      () => usecase.execute(payload, expectedParentFingerprint: 'fedcba98'),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestFileParseFailureReason.invalidMetadata,
        ),
      ),
    );
  });

  test('rejects unknown network wire values as invalid files', () {
    final payload = _manifestPayload.replaceFirst(
      '"network":"liquidMainnet"',
      '"network":"solanaMainnet"',
    );

    expect(
      () => usecase.execute(payload, expectedParentFingerprint: 'fedcba98'),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestFileParseFailureReason.invalidMetadata,
        ),
      ),
    );
  });

  test('rejects wrong-case network wire values as invalid files', () {
    final payload = _manifestPayload.replaceFirst(
      '"network":"bitcoinMainnet"',
      '"network":"BitcoinMainnet"',
    );

    expect(
      () => usecase.execute(payload, expectedParentFingerprint: 'fedcba98'),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestFileParseFailureReason.invalidMetadata,
        ),
      ),
    );
  });

  test('rejects unknown script type wire values as invalid files', () {
    final payload = _manifestPayload.replaceFirst(
      '"scriptType":"bip84",'
          '"createdAt":11',
      '"scriptType":"bip86",'
          '"createdAt":11',
    );

    expect(
      () => usecase.execute(payload, expectedParentFingerprint: 'fedcba98'),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestFileParseFailureReason.invalidMetadata,
        ),
      ),
    );
  });

  test('rejects non-wallet reservations in wallet manifest files', () {
    final payload = _manifestPayload
        .replaceFirst('btcpay_wallet_seed', 'nostr_wallet_manifest_key')
        .replaceFirst('walletSeed', 'nonWalletNostrKey')
        .replaceFirst('btcpay', 'nostr')
        .replaceFirst('39,"bip85Index":100', '9000,"bip85Index":1')
        .replaceFirst("39'/0'/12'/100'", "9000'/1'/1'")
        .replaceFirst("39'/0'/12'/100'", "9000'/1'/1'");

    expect(
      () => usecase.execute(payload, expectedParentFingerprint: 'fedcba98'),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestFileParseFailureReason.invalidMetadata,
        ),
      ),
    );
  });

  test('parses Lightning Address wallet manifests after activation', () {
    final payload = _manifestPayloadForReservation(
      reservationId: 'lightning_address_wallet_seed',
      path: "39'/0'/12'/101'",
      ownerFeature: 'lightningAddress',
      bip85Application: 39,
      bip85Index: 101,
      materializations: _lightningAddressMaterialization,
    );

    // LN is exportable (pr07) and, from pr11, recoverable: the import plan
    // carries it and restore materializes it flagged requiresProductReactivation
    // (R2-KC3/F1b; recovery added by this PR).
    final plan = usecase.execute(
      payload,
      expectedParentFingerprint: 'fedcba98',
    );
    expect(plan.entries.single.reservationId, 'lightning_address_wallet_seed');
    expect(plan.entries.single.ownerFeature, 'lightningAddress');
    expect(plan.entries.single.bip85DerivationPath, "39'/0'/12'/101'");
    expect(plan.entries.single.bip85Index, 101);
  });

  test('parses Payment Page wallet manifests into import plans', () {
    final payload = _manifestPayloadForReservation(
      reservationId: 'payment_page_wallet_seed',
      path: "39'/0'/12'/102'",
      ownerFeature: 'paymentPage',
      bip85Application: 39,
      bip85Index: 102,
      materializations: _lightningAddressMaterialization,
    );

    final plan = usecase.execute(
      payload,
      expectedParentFingerprint: 'fedcba98',
    );
    expect(plan.entries.single.reservationId, 'payment_page_wallet_seed');
    expect(plan.entries.single.bip85DerivationPath, "39'/0'/12'/102'");
  });

  test('rejects duplicate wallet materializations in the same entry', () {
    final duplicate =
        '{"type":"wallet","walletId":"btc-wallet",'
        '"childSeedFingerprint":"0123abcd","network":"bitcoinMainnet",'
        '"scriptType":"bip84",'
        '"createdAt":10,"updatedAt":10},';
    final payload = _manifestPayload.replaceFirst(
      '"materializations":[',
      '"materializations":[$duplicate',
    );

    // The file entity rejects duplicate wallet ids at decode time.
    expect(
      () => usecase.execute(payload, expectedParentFingerprint: 'fedcba98'),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestFileParseFailureReason.invalidMetadata,
        ),
      ),
    );
  });

  test('rejects duplicate entry ids', () {
    final duplicateEntry =
        '{"entryId":"fedcba98:39\'/0\'/12\'/100\'",'
        '"bip85DerivationPath":"39\'/0\'/12\'/100\'",'
        '"reservationId":"btcpay_wallet_seed","entryType":"walletSeed",'
        '"ownerFeature":"btcpay","bip85Application":39,"bip85Index":100,'
        '"createdAt":10,"updatedAt":12,"materializations":[{"type":"wallet",'
        '"walletId":"duplicate-wallet","childSeedFingerprint":"0123abcd",'
        '"network":"bitcoinMainnet",'
        '"scriptType":"bip84","createdAt":10,"updatedAt":10}]}';
    final payload = _manifestPayload.replaceFirst(
      ']}]}',
      ']},$duplicateEntry]}',
    );

    // The file entity rejects duplicate entry ids at decode time.
    expect(
      () => usecase.execute(payload, expectedParentFingerprint: 'fedcba98'),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestFileParseFailureReason.invalidMetadata,
        ),
      ),
    );
  });

  test('classifies newer format versions as unsupported, not malformed', () {
    final payload = _manifestPayload.replaceFirst('"version":1', '"version":2');

    expect(
      () => codec.decode(payload),
      throwsA(
        isA<KeychainManifestUnsupportedVersionException>().having(
          (error) => error.version,
          'version',
          2,
        ),
      ),
    );
  });

  test('surfaces a newer-version file as unsupported through execute', () {
    // The typed unsupported-version signal must survive the use-case, not be
    // remapped to the generic invalid-file path: PR23 renders "update the app",
    // never "no backup found" (KC-2).
    final payload = _manifestPayload.replaceFirst('"version":1', '"version":2');

    expect(
      () => usecase.execute(payload, expectedParentFingerprint: 'fedcba98'),
      throwsA(isA<KeychainManifestUnsupportedVersionException>()),
    );
  });

  test('classifies a non-integer version as malformed', () {
    final payload = _manifestPayload.replaceFirst(
      '"version":1',
      '"version":"1"',
    );

    expect(
      () => codec.decode(payload),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestFileParseFailureReason.malformedFile,
        ),
      ),
    );
  });

  test('classifies a missing version as malformed', () {
    final payload = _manifestPayload.replaceFirst('"version":1,', '');

    expect(
      () => codec.decode(payload),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestFileParseFailureReason.malformedFile,
        ),
      ),
    );
  });

  test('rejects a declared entry count that mismatches the entries', () {
    final payload = _manifestPayload.replaceFirst(
      '"entryCount":1',
      '"entryCount":2',
    );

    expect(
      () => codec.decode(payload),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestFileParseFailureReason.invalidMetadata,
        ),
      ),
    );
  });

  test('rejects a declared materialization count that mismatches the '
      'materializations', () {
    final payload = _manifestPayload.replaceFirst(
      '"materializationCount":2',
      '"materializationCount":3',
    );

    expect(
      () => codec.decode(payload),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestFileParseFailureReason.invalidMetadata,
        ),
      ),
    );
  });

  test('rejects stale inventory timestamps', () {
    final payload = _manifestPayload.replaceFirst(
      '"inventoryUpdatedAt":12',
      '"inventoryUpdatedAt":10',
    );

    expect(
      () => codec.decode(payload),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestFileParseFailureReason.invalidMetadata,
        ),
      ),
    );
  });
}

const _emptyManifestPayload =
    '{"version":1,"parentFingerprint":"fedcba98","generatedAt":20,'
    '"inventoryUpdatedAt":0,"entryCount":0,"materializationCount":0,'
    '"entries":[]}';

const _manifestPayload =
    '{"version":1,"parentFingerprint":"fedcba98","generatedAt":20,'
    '"inventoryUpdatedAt":12,"entryCount":1,"materializationCount":2,'
    '"entries":[{"entryId":"fedcba98:39\'/0\'/12\'/100\'",'
    '"bip85DerivationPath":"39\'/0\'/12\'/100\'",'
    '"reservationId":"btcpay_wallet_seed","entryType":"walletSeed",'
    '"ownerFeature":"btcpay","bip85Application":39,"bip85Index":100,'
    '"createdAt":10,"updatedAt":12,"materializations":[{"type":"wallet",'
    '"walletId":"btc-wallet","childSeedFingerprint":"0123abcd",'
    '"network":"bitcoinMainnet","scriptType":"bip84",'
    '"createdAt":10,"updatedAt":10},{"type":"wallet",'
    '"walletId":"lbtc-wallet","childSeedFingerprint":"0123abcd",'
    '"network":"liquidMainnet","scriptType":"bip84",'
    '"createdAt":11,"updatedAt":11}]}]}';

const _lightningAddressMaterialization =
    '{"type":"wallet","walletId":"lightning-address-wallet",'
    '"childSeedFingerprint":"0123abcd","network":"liquidMainnet",'
    '"scriptType":"bip84",'
    '"createdAt":10,"updatedAt":10}';

String _manifestPayloadForReservation({
  required String reservationId,
  required String path,
  required String ownerFeature,
  required int bip85Application,
  required int bip85Index,
  String? materializations,
}) {
  final payload = _manifestPayload
      .replaceFirst("fedcba98:39'/0'/12'/100'", 'fedcba98:$path')
      .replaceFirst("39'/0'/12'/100'", path)
      .replaceFirst('btcpay_wallet_seed', reservationId)
      .replaceFirst('btcpay', ownerFeature)
      .replaceFirst(
        '"bip85Application":39',
        '"bip85Application":$bip85Application',
      )
      .replaceFirst('"bip85Index":100', '"bip85Index":$bip85Index');
  if (materializations == null) return payload;
  // The base payload carries two materializations; replacing them with a
  // single one keeps the declared materialization count consistent.
  return payload
      .replaceFirst('"materializationCount":2', '"materializationCount":1')
      .replaceFirst(
        RegExp(r'"materializations":\[[^\]]+\]'),
        '"materializations":[$materializations]',
      );
}
