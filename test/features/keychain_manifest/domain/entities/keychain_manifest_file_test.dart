import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_file.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts entries whose BIP85 metadata matches the path', () {
    final entry = _entry();

    expect(entry.bip85Application, 39);
    expect(entry.bip85Index, 100);
  });

  test('rejects a BIP85 application that mismatches the first path segment', () {
    expect(
      () => _entry(bip85Application: 83696968),
      throwsA(
        isA<KeychainManifestInvalidEntryException>().having(
          (error) => error.type,
          'type',
          KeychainManifestExceptionType.invalidEntry,
        ),
      ),
    );
  });

  test('rejects a BIP85 index that mismatches the last path segment', () {
    expect(
      () => _entry(bip85DerivationPath: "39'/0'/12'/101'"),
      throwsA(
        isA<KeychainManifestInvalidEntryException>().having(
          (error) => error.type,
          'type',
          KeychainManifestExceptionType.invalidEntry,
        ),
      ),
    );
  });
}

KeychainManifestFileEntry _entry({
  String bip85DerivationPath = "39'/0'/12'/100'",
  int bip85Application = 39,
  int bip85Index = 100,
}) {
  final entryId = "fedcba98:$bip85DerivationPath";
  return KeychainManifestFileEntry(
    entryId: entryId,
    parentFingerprint: 'fedcba98',
    bip85DerivationPath: bip85DerivationPath,
    reservationId: 'btcpay_wallet_seed',
    entryType: 'walletSeed',
    ownerFeature: 'btcpay',
    bip85Application: bip85Application,
    bip85Index: bip85Index,
    createdAt: 10,
    updatedAt: 10,
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
    ],
  );
}
