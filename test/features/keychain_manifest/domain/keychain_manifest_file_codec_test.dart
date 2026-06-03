import 'dart:convert';

import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_file_codec.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = KeychainManifestFileCodec();

  test('encodes deterministic manifest file JSON', () {
    final payload = codec.encode(_manifestFile());

    expect(payload, _goldenPayload);
  });

  test('emits the v1 manifest file schema', () {
    final decoded = jsonDecode(codec.encode(_manifestFile()));

    expect(decoded, isA<Map<String, Object?>>());
    final json = decoded as Map<String, Object?>;
    expect(json.keys, [
      'version',
      'parentFingerprint',
      'generatedAt',
      'updatedAt',
      'entries',
    ]);
    expect(json['version'], 1);
    expect(json['parentFingerprint'], 'fedcba98');
    expect(json['generatedAt'], 20);
    expect(json['updatedAt'], 12);

    final entries = json['entries'] as List<Object?>;
    expect(entries, hasLength(1));
    final entry = entries.single as Map<String, Object?>;
    expect(entry['entryId'], "fedcba98:39'/0'/12'/100'");
    expect(entry['bip85DerivationPath'], "39'/0'/12'/100'");
    expect(entry['reservationId'], 'btcpay_wallet_seed');
    expect(entry['entryType'], 'walletSeed');
    expect(entry['ownerFeature'], 'btcpay');
    expect(entry['bip85Application'], 39);
    expect(entry['bip85Index'], 100);

    final materializations = entry['materializations'] as List<Object?>;
    expect(materializations, hasLength(2));
    final materialization = materializations.first as Map<String, Object?>;
    expect(materialization['type'], 'wallet');
    expect(materialization['walletId'], 'btc-wallet');
    expect(materialization['childSeedFingerprint'], '0123abcd');
    expect(materialization['network'], 'bitcoinMainnet');
    expect(materialization['scriptType'], 'bip84');
  });
}

KeychainManifestFile _manifestFile() {
  final entryId = "fedcba98:39'/0'/12'/100'";
  return KeychainManifestFile(
    parentFingerprint: 'fedcba98',
    generatedAt: 20,
    updatedAt: 12,
    entries: [
      KeychainManifestFileEntry(
        entryId: entryId,
        parentFingerprint: 'fedcba98',
        bip85DerivationPath: "39'/0'/12'/100'",
        reservationId: 'btcpay_wallet_seed',
        entryType: 'walletSeed',
        ownerFeature: 'btcpay',
        bip85Application: 39,
        bip85Index: 100,
        createdAt: 10,
        updatedAt: 12,
        materializations: [
          KeychainManifestFileWalletMaterialization(
            walletId: 'btc-wallet',
            entryId: entryId,
            childSeedFingerprint: '0123abcd',
            network: 'bitcoinMainnet',
            scriptType: 'bip84',
            createdAt: 10,
            updatedAt: 10,
          ),
          KeychainManifestFileWalletMaterialization(
            walletId: 'lbtc-wallet',
            entryId: entryId,
            childSeedFingerprint: '0123abcd',
            network: 'liquidMainnet',
            scriptType: 'bip84',
            createdAt: 11,
            updatedAt: 11,
          ),
        ],
      ),
    ],
  );
}

const _goldenPayload =
    '{"version":1,"parentFingerprint":"fedcba98","generatedAt":20,'
    '"updatedAt":12,"entries":[{"entryId":"fedcba98:39\'/0\'/12\'/100\'",'
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
