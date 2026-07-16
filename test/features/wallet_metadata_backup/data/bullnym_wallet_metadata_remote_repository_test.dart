import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/bullnym_wallet_metadata_remote_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_snapshot_codec.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_encrypted_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_key_material.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_remote_head.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_snapshot_cryptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late _MockBullnymFacade bullnym;
  late _MockNostrIdentityFacade identity;
  late _MockSnapshotCryptor cryptor;
  late BullnymWalletMetadataRemoteRepository repository;

  setUpAll(() {
    registerFallbackValue(
      BullnymAuthSigner(npubHex: 'fallback', signHashHex: (_) => 'fallback'),
    );
    registerFallbackValue(BullnymBackupStream.walletMetadata);
    registerFallbackValue(BullnymBackupHead.absent(generation: 0, etag: null));
    registerFallbackValue(_ciphertext(0));
    registerFallbackValue(_keyMaterial);
  });

  setUp(() {
    bullnym = _MockBullnymFacade();
    identity = _MockNostrIdentityFacade();
    cryptor = _MockSnapshotCryptor();
    when(
      () => identity.deriveWalletMetadataPublicKeyFromXprv(any()),
    ).thenReturn(_metadataPublicKey);
    when(
      () => identity.signWalletMetadataHashFromXprv(
        xprvBase58: any(named: 'xprvBase58'),
        messageHashHex: any(named: 'messageHashHex'),
      ),
    ).thenReturn('signed-hash');
    repository = BullnymWalletMetadataRemoteRepository(
      bullnym: bullnym,
      snapshots: cryptor,
      identity: identity,
    );
  });

  test('fetches and decrypts the wallet metadata stream', () async {
    final ciphertext = _ciphertext(1);
    final snapshot = _snapshot();
    when(
      () => bullnym.fetchBackup(
        signer: any(named: 'signer'),
        stream: BullnymBackupStream.walletMetadata,
      ),
    ).thenAnswer(
      (_) async => Ok(
        BullnymBackupHead.present(
          generation: 7,
          etag: 'a' * 64,
          ciphertext: ciphertext,
          ciphertextSha256: 'b' * 64,
          updatedAtSecs: 123,
        ),
      ),
    );
    when(
      () => cryptor.decrypt(
        keyMaterial: _keyMaterial,
        ciphertext: ciphertext.value,
      ),
    ).thenReturn(Ok(snapshot));

    final result = await repository.fetch(keyMaterial: _keyMaterial);

    final present = (result as Ok).value as WalletMetadataRemotePresent;
    expect(present.head.generation, 7);
    expect(present.head.etag, 'a' * 64);
    expect(present.head.snapshot, same(snapshot));
    final signer =
        verify(
              () => bullnym.fetchBackup(
                signer: captureAny(named: 'signer'),
                stream: BullnymBackupStream.walletMetadata,
              ),
            ).captured.single
            as BullnymAuthSigner;
    expect(signer.npubHex, _metadataPublicKey);
    expect(await signer.signHashHex('hash'), 'signed-hash');
  });

  test(
    'maps conditional store conflicts and passes only the CAS checkpoint',
    () async {
      when(
        () => bullnym.storeBackup(
          signer: any(named: 'signer'),
          stream: BullnymBackupStream.walletMetadata,
          currentHead: any(named: 'currentHead'),
          ciphertext: any(named: 'ciphertext'),
        ),
      ).thenAnswer(
        (_) async => const Err(
          BullnymFailure.serverRejectedRequest(
            code: 'BackupHeadConflict',
            logMessage: 'stale head',
            statusCode: 409,
            retryable: true,
          ),
        ),
      );

      final result = await repository.store(
        keyMaterial: _keyMaterial,
        snapshot: WalletMetadataEncryptedSnapshot(
          plaintext: _snapshot(),
          ciphertext: _ciphertext(2).value,
        ),
        generation: 8,
        expectedEtag: 'c' * 64,
      );

      expect(
        (result as Err).failure,
        isA<WalletMetadataBackupConflictFailure>(),
      );
      final head =
          verify(
                () => bullnym.storeBackup(
                  signer: any(named: 'signer'),
                  stream: BullnymBackupStream.walletMetadata,
                  currentHead: captureAny(named: 'currentHead'),
                  ciphertext: any(named: 'ciphertext'),
                ),
              ).captured.single
              as BullnymBackupHead;
      expect(head.found, isFalse);
      expect(head.generation, 7);
      expect(head.etag, 'c' * 64);
    },
  );

  test('fetches the authoritative head before conditional deletion', () async {
    final head = BullnymBackupHead.present(
      generation: 8,
      etag: 'd' * 64,
      ciphertext: _ciphertext(3),
      ciphertextSha256: 'e' * 64,
      updatedAtSecs: 456,
    );
    when(
      () => bullnym.fetchBackup(
        signer: any(named: 'signer'),
        stream: BullnymBackupStream.walletMetadata,
      ),
    ).thenAnswer((_) async => Ok(head));
    when(
      () => bullnym.deleteBackup(
        signer: any(named: 'signer'),
        stream: BullnymBackupStream.walletMetadata,
        currentHead: head,
      ),
    ).thenAnswer(
      (_) async => const Ok(
        BullnymBackupDeleteReceipt(
          generation: 9,
          etag:
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        ),
      ),
    );

    expect(await repository.delete(keyMaterial: _keyMaterial), isA<Ok>());
    verify(
      () => bullnym.deleteBackup(
        signer: any(named: 'signer'),
        stream: BullnymBackupStream.walletMetadata,
        currentHead: head,
      ),
    ).called(1);
  });

  test('does not send delete for a generation-zero absence', () async {
    when(
      () => bullnym.fetchBackup(
        signer: any(named: 'signer'),
        stream: BullnymBackupStream.walletMetadata,
      ),
    ).thenAnswer(
      (_) async => Ok(BullnymBackupHead.absent(generation: 0, etag: null)),
    );

    expect(await repository.delete(keyMaterial: _keyMaterial), isA<Ok>());
    verifyNever(
      () => bullnym.deleteBackup(
        signer: any(named: 'signer'),
        stream: BullnymBackupStream.walletMetadata,
        currentHead: any(named: 'currentHead'),
      ),
    );
  });
}

AuthenticatedBackupCiphertext _ciphertext(int byte) {
  return AuthenticatedBackupCiphertext(
    base64.encode(List<int>.filled(64, byte)),
  );
}

WalletMetadataSnapshot _snapshot() {
  const codec = WalletMetadataSnapshotCodec();
  final record = WalletMetadataRecord(
    type: 'labels.bip329',
    version: 1,
    scope: const {'kind': 'global'},
    recordId: 'record-1',
    payload: const {'type': 'tx', 'ref': 'ref', 'label': 'label'},
  );
  final section = WalletMetadataSection(
    type: record.type,
    versions: const [1],
    recordCount: 1,
    recordsHash: codec.recordsHash([record]),
  );
  return WalletMetadataSnapshot(
    parentFingerprint: _keyMaterial.parentFingerprint,
    revision: 1,
    createdAt: 10,
    recordsHash: codec.recordsHash([record]),
    recordCount: 1,
    sections: [section],
    records: [record],
  );
}

final class _MockBullnymFacade extends Mock implements BullnymFacade {}

final class _MockNostrIdentityFacade extends Mock
    implements NostrIdentityFacade {}

final class _MockSnapshotCryptor extends Mock
    implements WalletMetadataSnapshotCryptor {}

final _keyMaterial = WalletMetadataKeyMaterial(
  xprvBase58: 'xprv',
  parentFingerprint: '627ef3a6',
);

const _metadataPublicKey =
    '21ee43d352f3506c8cef5ee18f028efec0a2f71c510638afd0f7869f630a7dfd';
