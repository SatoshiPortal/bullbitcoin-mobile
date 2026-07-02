import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const usecase = ParseKeychainManifestFileUsecase();

  test('validates registered reservation metadata', () {
    final plan = usecase.execute(_manifestPayload);

    expect(plan.parentFingerprint, 'fedcba98');
    expect(plan.entries.single.reservationId, 'btcpay_wallet_seed');
    expect(plan.entries.single.bip85DerivationPath, "39'/0'/12'/100'");
    expect(plan.walletMaterializations, hasLength(2));
  });

  test('rejects unknown reservations', () {
    final payload = _manifestPayload.replaceFirst(
      'btcpay_wallet_seed',
      'unknown_wallet_seed',
    );

    expect(
      () => usecase.execute(payload),
      throwsA(
        isA<KeychainManifestFileParseException>().having(
          (error) => error.type,
          'type',
          KeychainManifestExceptionType.fileParse,
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
      () => usecase.execute(payload),
      throwsA(isA<KeychainManifestFileParseException>()),
    );
  });

  test('rejects reservation metadata mismatches', () {
    final payload = _manifestPayload.replaceFirst(
      '"ownerFeature":"btcpay"',
      '"ownerFeature":"other_feature"',
    );

    expect(
      () => usecase.execute(payload),
      throwsA(isA<KeychainManifestFileParseException>()),
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

    expect(
      () => usecase.execute(payload),
      throwsA(isA<KeychainManifestFileParseException>()),
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

    expect(
      () => usecase.execute(payload),
      throwsA(isA<KeychainManifestFileParseException>()),
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
