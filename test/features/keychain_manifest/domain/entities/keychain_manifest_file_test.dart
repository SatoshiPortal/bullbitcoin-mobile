import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_file.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts entries whose BIP85 metadata matches the path', () {
    final entry = _entry();

    expect(entry.bip85Application, 39);
    expect(entry.bip85Index, 100);
  });

  test(
    'rejects a BIP85 application that mismatches the first path segment',
    () {
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
    },
  );

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

  test('accepts distinct entry and wallet identities in a file', () {
    final manifestFile = KeychainManifestFile(
      parentFingerprint: 'fedcba98',
      generatedAt: 20,
      entries: [
        _entry(),
        _entry(
          bip85DerivationPath: "39'/0'/12'/101'",
          bip85Index: 101,
          walletId: 'other-wallet',
        ),
      ],
    );

    expect(manifestFile.entries, hasLength(2));
  });

  test('derives integrity counts from the actual entries', () {
    final manifestFile = KeychainManifestFile(
      parentFingerprint: 'fedcba98',
      generatedAt: 20,
      entries: [
        _entry(),
        _entry(
          bip85DerivationPath: "39'/0'/12'/101'",
          bip85Index: 101,
          walletId: 'other-wallet',
        ),
      ],
    );

    expect(manifestFile.entryCount, 2);
    expect(manifestFile.materializationCount, 2);
  });

  test('derives zero counts for an empty manifest file', () {
    final manifestFile = KeychainManifestFile(
      parentFingerprint: 'fedcba98',
      generatedAt: 20,
      entries: [],
    );

    expect(manifestFile.entryCount, 0);
    expect(manifestFile.materializationCount, 0);
  });

  test('rejects an entry count that mismatches the actual entries', () {
    expect(
      () => KeychainManifestFile(
        parentFingerprint: 'fedcba98',
        generatedAt: 20,
        entryCount: 2,
        entries: [_entry()],
      ),
      throwsA(
        isA<KeychainManifestInvalidEntryException>().having(
          (error) => error.type,
          'type',
          KeychainManifestExceptionType.invalidEntry,
        ),
      ),
    );
  });

  test(
    'rejects a materialization count that mismatches the materializations',
    () {
      expect(
        () => KeychainManifestFile(
          parentFingerprint: 'fedcba98',
          generatedAt: 20,
          materializationCount: 3,
          entries: [_entry()],
        ),
        throwsA(
          isA<KeychainManifestInvalidEntryException>().having(
            (error) => error.type,
            'type',
            KeychainManifestExceptionType.invalidEntry,
          ),
        ),
      );
    },
  );

  test('rejects duplicate entry ids across manifest file entries', () {
    expect(
      () => KeychainManifestFile(
        parentFingerprint: 'fedcba98',
        generatedAt: 20,
        entries: [
          _entry(),
          _entry(walletId: 'other-wallet'),
        ],
      ),
      throwsA(
        isA<KeychainManifestInvalidEntryException>().having(
          (error) => error.type,
          'type',
          KeychainManifestExceptionType.invalidEntry,
        ),
      ),
    );
  });

  test('rejects duplicate wallet ids across all materializations', () {
    expect(
      () => KeychainManifestFile(
        parentFingerprint: 'fedcba98',
        generatedAt: 20,
        entries: [
          _entry(),
          _entry(bip85DerivationPath: "39'/0'/12'/101'", bip85Index: 101),
        ],
      ),
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
  String walletId = 'btc-wallet',
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
        walletId: walletId,
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
