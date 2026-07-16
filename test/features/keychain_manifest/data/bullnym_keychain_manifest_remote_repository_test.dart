import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/data/bullnym_keychain_manifest_remote_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_remote_backup.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

final class _MockBullnymFacade extends Mock implements BullnymFacade {}

void main() {
  late _MockBullnymFacade bullnym;
  late BullnymKeychainManifestRemoteRepository repository;

  final ciphertext = AuthenticatedBackupCiphertext(
    base64.encode(List<int>.generate(64, (index) => index)),
  );
  final signer = KeychainManifestBackupSigner(
    publicKeyHex: '11' * 32,
    signHashHex: (_) => '22' * 64,
  );

  setUpAll(() {
    registerFallbackValue(
      BullnymAuthSigner(npubHex: '00' * 32, signHashHex: (_) => ''),
    );
    registerFallbackValue(BullnymBackupStream.keychainManifest);
    registerFallbackValue(BullnymBackupHead.absent(generation: 0, etag: null));
    registerFallbackValue(ciphertext);
  });

  setUp(() {
    bullnym = _MockBullnymFacade();
    repository = BullnymKeychainManifestRemoteRepository(bullnym);
  });

  test(
    'reconstructs the current ciphertext hash for conditional store',
    () async {
      when(
        () => bullnym.storeBackup(
          signer: any(named: 'signer'),
          stream: any(named: 'stream'),
          currentHead: any(named: 'currentHead'),
          ciphertext: any(named: 'ciphertext'),
        ),
      ).thenAnswer(
        (_) async =>
            Ok(BullnymBackupStoreReceipt(generation: 3, etag: '33' * 32)),
      );

      final checkpoint = await repository.store(
        signer: signer,
        current: KeychainManifestRemoteBackup(
          generation: 2,
          etag: '44' * 32,
          ciphertext: ciphertext,
        ),
        ciphertext: ciphertext,
      );

      final captured =
          verify(
                () => bullnym.storeBackup(
                  signer: any(named: 'signer'),
                  stream: BullnymBackupStream.keychainManifest,
                  currentHead: captureAny(named: 'currentHead'),
                  ciphertext: ciphertext,
                ),
              ).captured.single
              as BullnymBackupHead;
      expect(
        captured.ciphertextSha256,
        sha256.convert(base64.decode(ciphertext.value)).toString(),
      );
      expect(checkpoint.generation, 3);
      expect(checkpoint.etag, '33' * 32);
    },
  );

  test('maps a typed Bullnym CAS conflict into the keychain domain', () async {
    when(
      () => bullnym.fetchBackup(
        signer: any(named: 'signer'),
        stream: BullnymBackupStream.keychainManifest,
      ),
    ).thenAnswer(
      (_) async => const Err(
        BullnymFailure.serverRejectedRequest(
          code: 'BackupHeadConflict',
          logMessage: 'stale etag',
          statusCode: 409,
          retryable: false,
        ),
      ),
    );

    await expectLater(
      repository.fetch(signer),
      throwsA(
        isA<KeychainManifestRemoteException>().having(
          (error) => error.reason,
          'reason',
          KeychainManifestRemoteFailureReason.headConflict,
        ),
      ),
    );
  });
}
