import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_remote_backup.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_remote_repository.dart';

final class BullnymKeychainManifestRemoteRepository
    implements KeychainManifestRemoteRepository {
  final BullnymFacade bullnym;

  const BullnymKeychainManifestRemoteRepository(this.bullnym);

  BullnymAuthSigner _adapt(KeychainManifestBackupSigner signer) =>
      BullnymAuthSigner(
        npubHex: signer.publicKeyHex,
        signHashHex: signer.signHashHex,
      );

  @override
  Future<KeychainManifestRemoteBackup> fetch(
    KeychainManifestBackupSigner signer,
  ) async {
    try {
      final head = await bullnym.fetchBackup(
        signer: _adapt(signer),
        stream: BullnymBackupStream.keychainManifest,
      );
      return KeychainManifestRemoteBackup(
        generation: head.generation,
        etag: head.etag,
        ciphertext: head.ciphertext,
      );
    } on AuthenticatedBackupCipherException catch (error) {
      throw _mapCipherError(error);
    } on BullnymException catch (error) {
      throw _mapBullnymError(error);
    }
  }

  @override
  Future<KeychainManifestRemoteCheckpoint> store({
    required KeychainManifestBackupSigner signer,
    required KeychainManifestRemoteBackup current,
    required AuthenticatedBackupCiphertext ciphertext,
  }) async {
    try {
      final receipt = await bullnym.storeBackup(
        signer: _adapt(signer),
        stream: BullnymBackupStream.keychainManifest,
        currentHead: _toBullnymHead(current),
        ciphertext: ciphertext,
      );
      return KeychainManifestRemoteCheckpoint(
        generation: receipt.generation,
        etag: receipt.etag,
      );
    } on AuthenticatedBackupCipherException catch (error) {
      throw _mapCipherError(error);
    } on BullnymException catch (error) {
      throw _mapBullnymError(error);
    }
  }

  @override
  Future<KeychainManifestRemoteCheckpoint?> delete({
    required KeychainManifestBackupSigner signer,
    required KeychainManifestRemoteBackup current,
  }) async {
    try {
      final receipt = await bullnym.deleteBackup(
        signer: _adapt(signer),
        stream: BullnymBackupStream.keychainManifest,
        currentHead: _toBullnymHead(current),
      );
      if (receipt == null) return null;
      return KeychainManifestRemoteCheckpoint(
        generation: receipt.generation,
        etag: receipt.etag,
      );
    } on AuthenticatedBackupCipherException catch (error) {
      throw _mapCipherError(error);
    } on BullnymException catch (error) {
      throw _mapBullnymError(error);
    }
  }

  BullnymBackupHead _toBullnymHead(KeychainManifestRemoteBackup current) {
    final ciphertext = current.ciphertext;
    if (ciphertext == null) {
      return BullnymBackupHead.absent(
        generation: current.generation,
        etag: current.etag,
      );
    }
    return BullnymBackupHead.present(
      generation: current.generation,
      etag: current.etag!,
      ciphertext: ciphertext,
      ciphertextSha256: '',
      updatedAtSecs: 0,
    );
  }

  KeychainManifestRemoteException _mapCipherError(
    AuthenticatedBackupCipherException error,
  ) {
    return KeychainManifestRemoteException(
      error.message.contains('too large')
          ? KeychainManifestRemoteFailureReason.tooLarge
          : KeychainManifestRemoteFailureReason.invalid,
      cause: error,
    );
  }

  KeychainManifestRemoteException _mapBullnymError(BullnymException error) {
    final reason = switch (error.code) {
      'BackupHeadConflict' => KeychainManifestRemoteFailureReason.headConflict,
      'BackupBlobTooLarge' => KeychainManifestRemoteFailureReason.tooLarge,
      'InvalidServerResponse' => KeychainManifestRemoteFailureReason.invalid,
      _ => KeychainManifestRemoteFailureReason.unavailable,
    };
    return KeychainManifestRemoteException(reason, cause: error);
  }
}
