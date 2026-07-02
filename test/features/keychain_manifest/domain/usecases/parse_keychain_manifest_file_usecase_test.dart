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
    final oversized = 'a' * (KeychainManifestFileCodec.maxStringFieldLength + 1);
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
    final extraEntry =
        '{"entryId":"fedcba98:39\'/0\'/12\'/101\'",'
        '"bip85DerivationPath":"39\'/0\'/12\'/101\'",'
        '"reservationId":"btcpay_wallet_seed","entryType":"walletSeed",'
        '"ownerFeature":"btcpay","bip85Application":39,"bip85Index":101,'
        '"createdAt":10,"updatedAt":12,"materializations":[{"type":"wallet",'
        '"walletId":"extra-wallet","childSeedFingerprint":"0123abcd",'
        '"network":"bitcoinMainnet",'
        '"scriptType":"bip84","createdAt":10,"updatedAt":10}]}';
    final payload = _manifestPayload
        .replaceFirst(']}]}', ']},$extraEntry]}')
        .replaceFirst('"entryCount":1', '"entryCount":2')
        .replaceFirst('"materializationCount":2', '"materializationCount":3');

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
