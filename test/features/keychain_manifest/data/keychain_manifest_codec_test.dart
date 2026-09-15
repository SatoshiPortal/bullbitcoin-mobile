import 'dart:convert';

import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok;

import '../support/manifest_fixtures.dart';

void main() {
  const codec = KeychainManifestFileCodec();

  test('writes the frozen v1 payload byte-for-byte', () {
    expect(codec.encode(manifest()), canonicalWalletManifest);
  });

  test('writes a BIP85 chain as ordered steps, byte-for-byte', () {
    expect(
      codec.encode(manifest(entries: [backupIdentityChainEntry()])),
      canonicalBackupIdentityChainManifest,
    );
    final decoded =
        codec.decode(canonicalBackupIdentityChainManifest)
            as Ok<KeychainManifest, KeychainManifestFailure>;
    final entry = decoded.value.entries.single;
    expect(entry.derivationKind, KeychainManifestDerivationKind.bip85Chain);
    expect(entry.bip85ChainSteps, ["39'/0'/12'/104'", "128002'/100'/1'"]);
    expect(entry.derivationPath, "39'/0'/12'/104' > 128002'/100'/1'");
    expect(codec.encode(decoded.value), canonicalBackupIdentityChainManifest);
  });

  test('a chain must carry steps and nothing else may', () {
    final json =
        jsonDecode(canonicalBackupIdentityChainManifest)
            as Map<String, dynamic>;
    final entry =
        (json['entries'] as List<dynamic>).single as Map<String, dynamic>;
    final steps = entry['derivationSteps'];

    Object? decode(void Function(Map<String, dynamic>) mutate) {
      final copy = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      mutate((copy['entries'] as List<dynamic>).single as Map<String, dynamic>);
      return codec.decode(jsonEncode(copy));
    }

    // A chain spelled as one path string is refused.
    expect(
      decode((e) {
        e.remove('derivationSteps');
        e['derivationPath'] = "39'/0'/12'/104' > 128002'/100'/1'";
      }),
      isA<Err<KeychainManifest, KeychainManifestFailure>>(),
    );
    // Steps on a single-path kind are refused.
    expect(
      decode((e) {
        e['derivationKind'] = 'bip85';
        e['derivationPath'] = "128002'/100'/1'";
      }),
      isA<Err<KeychainManifest, KeychainManifestFailure>>(),
    );
    // One step is a path, not a chain.
    expect(
      decode((e) => e['derivationSteps'] = [(steps as List<dynamic>).first]),
      isA<Err<KeychainManifest, KeychainManifestFailure>>(),
    );
    // An intermediate step that is not an English BIP39 mnemonic derivation
    // cannot feed the next step.
    expect(
      decode(
        (e) => e['derivationSteps'] = ["128002'/5'/1'", "128002'/100'/1'"],
      ),
      isA<Err<KeychainManifest, KeychainManifestFailure>>(),
    );
    // A chain ending in a wallet is refused.
    expect(
      decode((e) {
        e['materializations'] = [
          {
            'type': 'wallet',
            'walletId': 'w',
            'childSeedFingerprint': 'fedcba98',
            'network': 'bitcoinMainnet',
            'scriptType': 'bip84',
            'provenance': 'bip85',
            'seedPassphraseUsed': false,
            'createdAt': 1,
            'updatedAt': 2,
          },
        ];
      }),
      isA<Err<KeychainManifest, KeychainManifestFailure>>(),
    );
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

  test('accepts conventional JSON whitespace', () {
    final formatted = const JsonEncoder.withIndent(
      '  ',
    ).convert(jsonDecode(canonicalWalletManifest));

    expect(
      codec.decode(formatted),
      isA<Ok<KeychainManifest, KeychainManifestFailure>>(),
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

  test('round-trips an optional wallet label', () {
    final entry = manifest().entries.single;
    final wallet = entry.materializations.single as KeychainManifestWallet;
    final labeled = KeychainManifestEntry(
      parentFingerprint: entry.parentFingerprint,
      derivationKind: entry.derivationKind,
      derivationPath: entry.derivationPath,
      description: entry.description,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      materializations: [
        KeychainManifestWallet(
          walletId: wallet.walletId,
          entryId: wallet.entryId,
          childSeedFingerprint: wallet.childSeedFingerprint,
          network: wallet.network,
          scriptType: wallet.scriptType,
          provenance: wallet.provenance,
          seedPassphraseUsed: wallet.seedPassphraseUsed,
          descriptor: wallet.descriptor,
          label: 'Savings',
          createdAt: wallet.createdAt,
          updatedAt: wallet.updatedAt,
        ),
      ],
    );

    final payload = codec.encode(manifest(entries: [labeled]));
    final decoded =
        codec.decode(payload) as Ok<KeychainManifest, KeychainManifestFailure>;

    expect(decoded.value.wallets.single.label, 'Savings');
    expect(payload, contains('"label":"Savings"'));
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
      json.remove('generatedAt');
      return jsonEncode(json);
    },
    'wrong field type': () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      json['generatedAt'] = '3';
      return jsonEncode(json);
    },
    'out-of-range timestamp': () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      json['generatedAt'] = 8640000000001;
      return jsonEncode(json);
    },
    'entry updated before creation': () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      final entry =
          (json['entries'] as List<dynamic>).single as Map<String, dynamic>;
      entry['createdAt'] = 2;
      entry['updatedAt'] = 1;
      return jsonEncode(json);
    },
    'materialization updated before creation': () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      final entry =
          (json['entries'] as List<dynamic>).single as Map<String, dynamic>;
      final materialization =
          (entry['materializations'] as List<dynamic>).single
              as Map<String, dynamic>;
      materialization['createdAt'] = 2;
      materialization['updatedAt'] = 1;
      return jsonEncode(json);
    },
    'derived entry id': () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      final entry =
          (json['entries'] as List<dynamic>).single as Map<String, dynamic>;
      entry['entryId'] = "73c5da0a:39'/0'/12'/100'";
      return jsonEncode(json);
    },
    'duplicate entry': () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      final entries = json['entries'] as List<dynamic>;
      entries.add(entries.first);
      return jsonEncode(json);
    },
    'too many materializations': () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      final entry =
          (json['entries'] as List<dynamic>).single as Map<String, dynamic>;
      final item = (entry['materializations'] as List<dynamic>).single;
      entry['materializations'] = List.filled(9, item);
      return jsonEncode(json);
    },
    'non-canonical path': () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      final entry =
          (json['entries'] as List<dynamic>).single as Map<String, dynamic>;
      entry['derivationPath'] = "39'/00'/12'/100'";
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
    'watch-only wallet provenance': () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      final entry =
          (json['entries'] as List<dynamic>).single as Map<String, dynamic>;
      final materialization =
          (entry['materializations'] as List<dynamic>).single
              as Map<String, dynamic>;
      materialization['provenance'] = 'watchOnly';
      return jsonEncode(json);
    },
    'external-signer wallet provenance': () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      final entry =
          (json['entries'] as List<dynamic>).single as Map<String, dynamic>;
      final materialization =
          (entry['materializations'] as List<dynamic>).single
              as Map<String, dynamic>;
      materialization['provenance'] = 'externalSigner';
      return jsonEncode(json);
    },
    'passphrase wallet without a descriptor': () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      final entry =
          (json['entries'] as List<dynamic>).single as Map<String, dynamic>;
      final materialization =
          (entry['materializations'] as List<dynamic>).single
              as Map<String, dynamic>;
      materialization['provenance'] = 'defaultSeedPassphrase';
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

  group('parse', () {
    final parse = ParseKeychainManifestFileUsecase(codec.decode);

    test('reuses the validated manifest without copying entry fields', () {
      final result = parse.execute(
        canonicalWalletManifest,
        expectedParentFingerprint: manifestFingerprint,
      );
      final parsed =
          (result as Ok<KeychainManifest, KeychainManifestFailure>).value;
      expect(parsed.entries.single.bip85DerivationPath, "39'/0'/12'/100'");
      expect(parsed.wallets.single.walletId, 'wallet-1');
    });

    test('rejects a different locally verified parent', () {
      final result = parse.execute(
        canonicalWalletManifest,
        expectedParentFingerprint: Fingerprint('00000000'),
      );
      expect(
        result,
        isA<Err<KeychainManifest, KeychainManifestFailure>>().having(
          (value) => value.failure,
          'failure',
          isA<KeychainManifestParentMismatchFailure>(),
        ),
      );
    });

    test('admits only the backup credential chains, as reserved keys', () {
      Object? parseChain(KeychainManifestEntry entry) => parse.execute(
        codec.encode(manifest(entries: [entry])),
        expectedParentFingerprint: manifestFingerprint,
      );

      expect(
        parseChain(backupIdentityChainEntry()),
        isA<Ok<KeychainManifest, KeychainManifestFailure>>(),
      );
      expect(
        parseChain(
          backupIdentityChainEntry(
            steps: const ["39'/0'/12'/104'", "128002'/101'/1'"],
          ),
        ),
        isA<Ok<KeychainManifest, KeychainManifestFailure>>(),
      );
      // Same second step on a different first step is not the credential.
      expect(
        parseChain(
          backupIdentityChainEntry(
            steps: const ["39'/0'/12'/100'", "128002'/100'/1'"],
          ),
        ),
        isA<Err<KeychainManifest, KeychainManifestFailure>>().having(
          (value) => value.failure,
          'failure',
          isA<KeychainManifestUnknownReservationFailure>(),
        ),
      );
      // The words followed by an unclaimed identity path is not either.
      expect(
        parseChain(
          backupIdentityChainEntry(
            steps: const ["39'/0'/12'/104'", "128002'/7'/1'"],
          ),
        ),
        isA<Err<KeychainManifest, KeychainManifestFailure>>(),
      );
      // A user-generated key cannot sit on the app's chain.
      expect(
        parseChain(
          backupIdentityChainEntry(
            keyKind: KeychainManifestNostrKeyKind.userGenerated,
          ),
        ),
        isA<Err<KeychainManifest, KeychainManifestFailure>>(),
      );
    });

    test('rejects an unknown derivation path', () {
      final json = jsonDecode(canonicalWalletManifest) as Map<String, dynamic>;
      final entry =
          (json['entries'] as List<dynamic>).single as Map<String, dynamic>;
      entry['derivationPath'] = "39'/0'/12'/999'";
      final result = parse.execute(
        jsonEncode(json),
        expectedParentFingerprint: manifestFingerprint,
      );
      expect(
        result,
        isA<Err<KeychainManifest, KeychainManifestFailure>>().having(
          (value) => value.failure,
          'failure',
          isA<KeychainManifestUnknownReservationFailure>(),
        ),
      );
    });

    test('rejects a default wallet derived from another seed', () {
      final childFingerprint = Fingerprint('fedcba98');
      const path = "m/84'/0'/0'";
      final entryId = KeychainManifestEntry.entryIdFor(
        parentFingerprint: manifestFingerprint,
        derivationKind: KeychainManifestDerivationKind.bip32,
        derivationPath: path,
        seedFingerprint: childFingerprint,
        network: Network.bitcoinMainnet,
      );
      final payload = codec.encode(
        manifest(
          entries: [
            KeychainManifestEntry(
              parentFingerprint: manifestFingerprint,
              derivationKind: KeychainManifestDerivationKind.bip32,
              derivationPath: path,
              createdAt: 1,
              updatedAt: 1,
              materializations: [
                KeychainManifestWallet(
                  walletId: 'wrong-default',
                  entryId: entryId,
                  childSeedFingerprint: childFingerprint,
                  network: Network.bitcoinMainnet,
                  scriptType: ScriptType.bip84,
                  provenance: WalletProvenance.defaultSeed,
                  seedPassphraseUsed: false,
                  createdAt: 1,
                  updatedAt: 1,
                ),
              ],
            ),
          ],
        ),
      );

      expect(
        parse.execute(payload, expectedParentFingerprint: manifestFingerprint),
        isA<Err<KeychainManifest, KeychainManifestFailure>>().having(
          (value) => value.failure,
          'failure',
          isA<KeychainManifestUnknownReservationFailure>(),
        ),
      );
    });
  });
}
