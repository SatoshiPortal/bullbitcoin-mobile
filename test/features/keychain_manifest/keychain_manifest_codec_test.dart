import 'dart:convert';

import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'support/manifest_fixtures.dart';

void main() {
  const codec = KeychainManifestFileCodec();

  test('writes the frozen v1 payload byte-for-byte', () {
    expect(codec.encode(manifest()), canonicalWalletManifest);
  });

  test('round-trips through the one canonical model', () {
    final decoded = codec.decode(canonicalWalletManifest);
    expect(decoded, isA<Ok<KeychainManifest, KeychainManifestFailure>>());
    expect(
      codec.encode(
        (decoded as Ok<KeychainManifest, KeychainManifestFailure>).value,
      ),
      canonicalWalletManifest,
    );
  });

  test('preserves an absent Nostr description as an absent field', () {
    final payload = codec.encode(
      manifest(entries: [nostrManifestEntry(description: null)]),
    );
    expect(payload, isNot(contains('description')));
    final decoded =
        codec.decode(payload) as Ok<KeychainManifest, KeychainManifestFailure>;
    expect(codec.encode(decoded.value), payload);
  });

  test('checks version before later fields', () {
    final result = codec.decode('{"version":2}');
    expect(
      result,
      isA<Err<KeychainManifest, KeychainManifestFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<KeychainManifestUnsupportedVersionFailure>(),
      ),
    );
  });

  final malformed = <String, String Function()>{
    'invalid JSON': () => '{',
    'non-object root': () => '[]',
    'missing required field': () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      json.remove('entryCount');
      return jsonEncode(json);
    },
    'wrong field type': () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      json['generatedAt'] = '3';
      return jsonEncode(json);
    },
    'wrong integrity count': () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      json['materializationCount'] = 2;
      return jsonEncode(json);
    },
    'wrong inventory timestamp': () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      json['inventoryUpdatedAt'] = 99;
      return jsonEncode(json);
    },
    'duplicate entry': () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      final entries = json['entries'] as List<dynamic>;
      entries.add(entries.first);
      json['entryCount'] = 2;
      json['materializationCount'] = 2;
      return jsonEncode(json);
    },
    'too many materializations': () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      final entry =
          (json['entries'] as List<dynamic>).single as Map<String, dynamic>;
      final item = (entry['materializations'] as List<dynamic>).single;
      entry['materializations'] = List.filled(9, item);
      json['materializationCount'] = 9;
      return jsonEncode(json);
    },
    'non-canonical path': () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      final entry =
          (json['entries'] as List<dynamic>).single as Map<String, dynamic>;
      entry['bip85DerivationPath'] = "39'/00'/12'/100'";
      return jsonEncode(json);
    },
    'invalid Nostr metadata': () {
      final json =
          jsonDecode(codec.encode(manifest(entries: [nostrManifestEntry()])))
              as Map<String, dynamic>;
      final entry =
          (json['entries'] as List<dynamic>).single as Map<String, dynamic>;
      final materialization =
          (entry['materializations'] as List<dynamic>).single
              as Map<String, dynamic>;
      materialization['purpose'] = '\u0000';
      return jsonEncode(json);
    },
  };
  for (final MapEntry(key: name, value: payload) in malformed.entries) {
    test('rejects $name', () {
      expect(
        codec.decode(payload()),
        isA<Err<KeychainManifest, KeychainManifestFailure>>().having(
          (value) => value.failure,
          'failure',
          isA<KeychainManifestMalformedFileFailure>(),
        ),
      );
    });
  }

  test('enforces the UTF-8 payload bound', () {
    expect(
      codec.decode('x' * (KeychainManifestFileCodec.maxPayloadSizeBytes + 1)),
      isA<Err<KeychainManifest, KeychainManifestFailure>>(),
    );
  });

  group('parse plan', () {
    const parse = ParseKeychainManifestFileUsecase(codec);

    test('reuses the validated manifest without copying entry fields', () {
      final result = parse.execute(
        canonicalWalletManifest,
        expectedParentFingerprint: manifestFingerprint,
      );
      final plan =
          (result as Ok<KeychainManifestImportPlan, KeychainManifestFailure>)
              .value;
      expect(plan.entries.single.reservationId, 'btcpay_wallet_seed');
      expect(plan.wallets.single.walletId, 'wallet-1');
    });

    test('rejects a different locally verified parent', () {
      final result = parse.execute(
        canonicalWalletManifest,
        expectedParentFingerprint: Fingerprint('00000000'),
      );
      expect(
        result,
        isA<Err<KeychainManifestImportPlan, KeychainManifestFailure>>().having(
          (value) => value.failure,
          'failure',
          isA<KeychainManifestParentMismatchFailure>(),
        ),
      );
    });

    test('rejects unknown reservation metadata', () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      final entry =
          (json['entries'] as List<dynamic>).single as Map<String, dynamic>;
      entry['reservationId'] = 'not_reserved';
      final result = parse.execute(
        jsonEncode(json),
        expectedParentFingerprint: manifestFingerprint,
      );
      expect(
        result,
        isA<Err<KeychainManifestImportPlan, KeychainManifestFailure>>().having(
          (value) => value.failure,
          'failure',
          isA<KeychainManifestUnknownReservationFailure>(),
        ),
      );
    });
  });
}
