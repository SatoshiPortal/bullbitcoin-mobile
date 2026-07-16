import 'dart:convert';

import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/data/recoverbull_keychain_manifest_encryption_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_backup_snapshot.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_file.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_remote_backup.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_encryption.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_remote_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/build_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/derive_keychain_manifest_encryption_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/sync_keychain_manifest_backup_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const _masterXprv =
    'xprv9s21ZrQH143K2LBWUUQRFXhucrQqBpKdRRxNVq2zBqsx8HVqFk2uYo8kmbaLLHRdqtQpUm98uKfu3vca1LqdGhUtyoFnCNkfmXRyPXLjbKb';
final _parentFingerprint = bip32.Bip32Keys.fromBase58(
  _masterXprv,
).fingerprintHex;

void main() {
  const encryption = RecoverBullKeychainManifestEncryptionRepository();
  final key = const DeriveKeychainManifestEncryptionKeyUsecase().execute(
    xprvBase58: _masterXprv,
    expectedParentFingerprint: _parentFingerprint,
  );
  final local = _manifest('btcpay_wallet_seed', generatedAt: 20);
  late _BuildManifest build;
  late _RemoteRepository remote;
  late _Identity identity;
  late SyncKeychainManifestBackupUsecase usecase;

  setUpAll(() {
    registerFallbackValue(
      KeychainManifestBackupSigner(
        publicKeyHex: 'aa' * 32,
        signHashHex: (_) => '11' * 64,
      ),
    );
    registerFallbackValue(
      KeychainManifestRemoteBackup(generation: 0, etag: null, ciphertext: null),
    );
    registerFallbackValue(
      AuthenticatedBackupCiphertext(base64.encode(List<int>.filled(64, 0))),
    );
  });

  setUp(() {
    build = _BuildManifest();
    remote = _RemoteRepository();
    identity = _Identity();
    when(
      () => build.execute(any(), now: any(named: 'now')),
    ).thenAnswer((_) async => local);
    when(
      () => identity.deriveWalletManifestPublicKeyFromXprv(any()),
    ).thenReturn('aa' * 32);
    when(
      () => identity.signWalletManifestHashFromXprv(
        xprvBase58: any(named: 'xprvBase58'),
        messageHashHex: any(named: 'messageHashHex'),
      ),
    ).thenReturn('11' * 64);
    usecase = SyncKeychainManifestBackupUsecase(
      buildManifestFile: build,
      encryption: encryption,
      remote: remote,
      identity: identity,
      parseManifest: const ParseKeychainManifestFileUsecase(
        codec: KeychainManifestFileCodec(),
        bip85Registry: Bip85RegistryFacade(),
      ),
    );
  });

  test('refetches and recomposes once after a head conflict', () async {
    final first = _head(
      encryption,
      key,
      _manifest('lightning_address_wallet_seed', generatedAt: 10),
      generation: 1,
    );
    final second = _head(
      encryption,
      key,
      _manifest('payment_page_wallet_seed', generatedAt: 11),
      generation: 2,
    );
    var fetches = 0;
    when(
      () => remote.fetch(any()),
    ).thenAnswer((_) async => fetches++ == 0 ? first : second);
    final stored = <AuthenticatedBackupCiphertext>[];
    var stores = 0;
    when(
      () => remote.store(
        signer: any(named: 'signer'),
        current: any(named: 'current'),
        ciphertext: any(named: 'ciphertext'),
      ),
    ).thenAnswer((invocation) async {
      stored.add(
        invocation.namedArguments[#ciphertext] as AuthenticatedBackupCiphertext,
      );
      if (stores++ == 0) {
        throw KeychainManifestRemoteException(
          KeychainManifestRemoteFailureReason.headConflict,
        );
      }
      return const KeychainManifestRemoteCheckpoint(
        generation: 3,
        etag: 'stored',
      );
    });

    final result = await _execute(usecase);

    expect(result.checkpoint.generation, 3);
    expect(stored, hasLength(2));
    final firstStored = encryption.decryptSnapshot(
      ciphertext: stored[0],
      key: key,
    );
    final secondStored = encryption.decryptSnapshot(
      ciphertext: stored[1],
      key: key,
    );
    expect(
      firstStored.manifestFile.entries.map((entry) => entry.reservationId),
      ['btcpay_wallet_seed', 'lightning_address_wallet_seed'],
    );
    expect(
      secondStored.manifestFile.entries.map((entry) => entry.reservationId),
      ['btcpay_wallet_seed', 'payment_page_wallet_seed'],
    );
  });

  test(
    'unchanged canonical inventory records the fetched head without store',
    () async {
      final remoteFile = _manifest('btcpay_wallet_seed', generatedAt: 10);
      final head = _head(encryption, key, remoteFile, generation: 4);
      when(() => remote.fetch(any())).thenAnswer((_) async => head);

      final result = await _execute(usecase);

      expect(result.checkpoint.generation, 4);
      expect(result.checkpoint.etag, head.etag);
      expect(
        result.contentHash,
        encryption.contentHash(
          KeychainManifestBackupSnapshot(manifestFile: remoteFile),
        ),
      );
      verifyNever(
        () => remote.store(
          signer: any(named: 'signer'),
          current: any(named: 'current'),
          ciphertext: any(named: 'ciphertext'),
        ),
      );
    },
  );

  test('corrupt authenticated ciphertext blocks overwrite', () async {
    when(() => remote.fetch(any())).thenAnswer(
      (_) async => KeychainManifestRemoteBackup(
        generation: 1,
        etag: 'head',
        ciphertext: AuthenticatedBackupCiphertext(
          base64.encode(List<int>.filled(64, 0)),
        ),
      ),
    );

    await expectLater(
      _execute(usecase),
      throwsA(isA<KeychainManifestEncryptionException>()),
    );
    verifyNever(
      () => remote.store(
        signer: any(named: 'signer'),
        current: any(named: 'current'),
        ciphertext: any(named: 'ciphertext'),
      ),
    );
  });

  test('newer snapshot versions block overwrite', () async {
    final ciphertext = const RecoverBullAuthenticatedBackupCipher().encrypt(
      plaintext: '{"version":2,"contentType":"newer","manifestFile":{}}',
      key: key.cipherKey,
    );
    when(() => remote.fetch(any())).thenAnswer(
      (_) async => KeychainManifestRemoteBackup(
        generation: 1,
        etag: 'head',
        ciphertext: ciphertext,
      ),
    );

    await expectLater(
      _execute(usecase),
      throwsA(isA<KeychainManifestUnsupportedVersionException>()),
    );
    verifyNever(
      () => remote.store(
        signer: any(named: 'signer'),
        current: any(named: 'current'),
        ciphertext: any(named: 'ciphertext'),
      ),
    );
  });

  test('semantically unsupported remote entries block overwrite', () async {
    final unsupported = _manifest(
      'unknown_wallet_seed',
      generatedAt: 10,
      path: "39'/0'/12'/199'",
      owner: 'unknown',
      index: 199,
    );
    when(() => remote.fetch(any())).thenAnswer(
      (_) async => _head(encryption, key, unsupported, generation: 1),
    );

    await expectLater(
      _execute(usecase),
      throwsA(isA<KeychainManifestFileParseException>()),
    );
    verifyNever(
      () => remote.store(
        signer: any(named: 'signer'),
        current: any(named: 'current'),
        ciphertext: any(named: 'ciphertext'),
      ),
    );
  });

  test('a second head conflict remains retryable dirty work', () async {
    var generation = 1;
    when(() => remote.fetch(any())).thenAnswer(
      (_) async => _head(
        encryption,
        key,
        _manifest('lightning_address_wallet_seed', generatedAt: generation),
        generation: generation++,
      ),
    );
    when(
      () => remote.store(
        signer: any(named: 'signer'),
        current: any(named: 'current'),
        ciphertext: any(named: 'ciphertext'),
      ),
    ).thenThrow(
      KeychainManifestRemoteException(
        KeychainManifestRemoteFailureReason.headConflict,
      ),
    );

    await expectLater(
      _execute(usecase),
      throwsA(
        isA<KeychainManifestRemoteException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestRemoteFailureReason.headConflict,
        ),
      ),
    );
    verify(() => remote.fetch(any())).called(2);
  });
}

Future<KeychainManifestBackupSyncResult> _execute(
  SyncKeychainManifestBackupUsecase usecase,
) => usecase.execute(
  parentFingerprint: _parentFingerprint,
  xprvBase58: _masterXprv,
  now: DateTime.fromMillisecondsSinceEpoch(30000, isUtc: true),
);

KeychainManifestRemoteBackup _head(
  RecoverBullKeychainManifestEncryptionRepository encryption,
  KeychainManifestEncryptionKey key,
  KeychainManifestFile file, {
  required int generation,
}) => KeychainManifestRemoteBackup(
  generation: generation,
  etag: 'etag-$generation',
  ciphertext: encryption.encryptSnapshot(
    snapshot: KeychainManifestBackupSnapshot(manifestFile: file),
    key: key,
  ),
);

KeychainManifestFile _manifest(
  String reservationId, {
  required int generatedAt,
  String? path,
  String? owner,
  int? index,
}) {
  final resolved = switch (reservationId) {
    'btcpay_wallet_seed' => ("39'/0'/12'/100'", 'btcpay', 100),
    'lightning_address_wallet_seed' => (
      "39'/0'/12'/101'",
      'lightningAddress',
      101,
    ),
    'payment_page_wallet_seed' => ("39'/0'/12'/102'", 'paymentPage', 102),
    _ => (path!, owner!, index!),
  };
  final entryId = '$_parentFingerprint:${resolved.$1}';
  return KeychainManifestFile(
    parentFingerprint: _parentFingerprint,
    generatedAt: generatedAt,
    entries: [
      KeychainManifestFileEntry(
        parentFingerprint: _parentFingerprint,
        bip85DerivationPath: resolved.$1,
        reservationId: reservationId,
        entryType: 'walletSeed',
        ownerFeature: resolved.$2,
        bip85Application: 39,
        bip85Index: resolved.$3,
        createdAt: 1,
        updatedAt: 1,
        materializations: [
          KeychainManifestFileWalletMaterialization(
            walletId: 'wallet-${resolved.$3}',
            entryId: entryId,
            childSeedFingerprint: '0123abcd',
            network: 'bitcoinMainnet',
            scriptType: 'bip84',
            createdAt: 1,
            updatedAt: 1,
          ),
        ],
      ),
    ],
  );
}

final class _BuildManifest extends Mock
    implements BuildKeychainManifestFileUsecase {}

final class _RemoteRepository extends Mock
    implements KeychainManifestRemoteRepository {}

final class _Identity extends Mock implements NostrIdentityFacade {}
