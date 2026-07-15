import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = KeychainManifestFileCodec();

  Matcher throwsParseFailure(KeychainManifestFileParseFailureReason reason) {
    return throwsA(
      isA<KeychainManifestFileParseException>().having(
        (error) => error.reason,
        'reason',
        reason,
      ),
    );
  }

  group('round trip', () {
    test('encode(decode(payload)) reproduces the payload byte-exact', () {
      expect(codec.encode(codec.decode(_manifestPayload)), _manifestPayload);
    });

    test('empty payloads round-trip byte-exact', () {
      expect(
        codec.encode(codec.decode(_emptyManifestPayload)),
        _emptyManifestPayload,
      );
    });
  });

  group('malformed payloads', () {
    test('rejects non-JSON payloads', () {
      expect(
        () => codec.decode('not a manifest'),
        throwsParseFailure(
          KeychainManifestFileParseFailureReason.malformedFile,
        ),
      );
    });

    test('rejects a top-level array', () {
      expect(
        () => codec.decode('[]'),
        throwsParseFailure(
          KeychainManifestFileParseFailureReason.malformedFile,
        ),
      );
    });

    test('rejects a top-level scalar', () {
      expect(
        () => codec.decode('1'),
        throwsParseFailure(
          KeychainManifestFileParseFailureReason.malformedFile,
        ),
      );
    });

    test('rejects a missing required field', () {
      final payload = _manifestPayload.replaceFirst('"generatedAt":20,', '');

      expect(
        () => codec.decode(payload),
        throwsParseFailure(
          KeychainManifestFileParseFailureReason.malformedFile,
        ),
      );
    });

    test('rejects a string where an integer is required', () {
      final payload = _manifestPayload.replaceFirst(
        '"generatedAt":20',
        '"generatedAt":"20"',
      );

      expect(
        () => codec.decode(payload),
        throwsParseFailure(
          KeychainManifestFileParseFailureReason.malformedFile,
        ),
      );
    });

    test('rejects a fractional number where an integer is required', () {
      final payload = _manifestPayload.replaceFirst(
        '"generatedAt":20',
        '"generatedAt":20.5',
      );

      expect(
        () => codec.decode(payload),
        throwsParseFailure(
          KeychainManifestFileParseFailureReason.malformedFile,
        ),
      );
    });

    test('rejects null for a required field', () {
      final payload = _manifestPayload.replaceFirst(
        '"parentFingerprint":"fedcba98"',
        '"parentFingerprint":null',
      );

      expect(
        () => codec.decode(payload),
        throwsParseFailure(
          KeychainManifestFileParseFailureReason.malformedFile,
        ),
      );
    });
  });

  group('inconsistent payloads', () {
    test('rejects negative timestamps', () {
      final payload = _manifestPayload.replaceFirst(
        '"generatedAt":20',
        '"generatedAt":-1',
      );

      expect(
        () => codec.decode(payload),
        throwsParseFailure(
          KeychainManifestFileParseFailureReason.invalidMetadata,
        ),
      );
    });

    test('rejects an entry id that mismatches the parent fingerprint', () {
      final payload = _manifestPayload.replaceFirst(
        '"entryId":"fedcba98:',
        '"entryId":"0123abcd:',
      );

      expect(
        () => codec.decode(payload),
        throwsParseFailure(
          KeychainManifestFileParseFailureReason.invalidMetadata,
        ),
      );
    });

    test('rejects a duplicate wallet id across entries', () {
      // Two self-consistent entries whose materializations claim the same
      // wallet id; local record uniqueness makes this file impossible.
      final secondEntry =
          '{"entryId":"fedcba98:39\'/0\'/12\'/101\'",'
          '"bip85DerivationPath":"39\'/0\'/12\'/101\'",'
          '"reservationId":"btcpay_wallet_seed","entryType":"walletSeed",'
          '"ownerFeature":"btcpay","bip85Application":39,"bip85Index":101,'
          '"createdAt":10,"updatedAt":10,"materializations":[{"type":"wallet",'
          '"walletId":"btc-wallet","childSeedFingerprint":"0123abcd",'
          '"network":"bitcoinMainnet","scriptType":"bip84",'
          '"createdAt":10,"updatedAt":10}]}';
      final payload = _manifestPayload
          .replaceFirst(']}]}', ']},$secondEntry]}')
          .replaceFirst('"entryCount":1', '"entryCount":2')
          .replaceFirst('"materializationCount":2', '"materializationCount":3');

      expect(
        () => codec.decode(payload),
        throwsParseFailure(
          KeychainManifestFileParseFailureReason.invalidMetadata,
        ),
      );
    });
  });

  group('forward compatibility', () {
    // Unknown fields are tolerated on read by design: a v1 reader accepts
    // payloads carrying additional fields from a newer writer and validates
    // only the specified v1 fields.
    test('tolerates unknown top-level fields', () {
      final payload = _manifestPayload.replaceFirst(
        '{"version":1,',
        '{"version":1,"futureField":true,',
      );

      expect(codec.decode(payload).entries, hasLength(1));
    });

    test('tolerates unknown entry and materialization fields', () {
      final payload = _manifestPayload
          .replaceFirst(
            '"bip85DerivationPath"',
            '"futureEntryField":"x","bip85DerivationPath"',
          )
          .replaceFirst(
            '"walletId":"btc-wallet"',
            '"futureMaterializationField":7,"walletId":"btc-wallet"',
          );

      final manifestFile = codec.decode(payload);

      expect(manifestFile.entries.single.materializations, hasLength(2));
    });
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
