import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_backup_wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_remote_backup.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_remote_import.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_encryption_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_remote_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/derive_keychain_manifest_encryption_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';

final class FetchKeychainManifestRemoteImportPlanUsecase {
  final KeychainManifestRemoteRepository remote;
  final KeychainManifestEncryptionRepository encryption;
  final ParseKeychainManifestFileUsecase parseManifest;
  final DeriveKeychainManifestEncryptionKeyUsecase deriveEncryptionKey;
  final NostrIdentityFacade identity;
  final KeychainManifestBackupWalletPort wallet;

  const FetchKeychainManifestRemoteImportPlanUsecase({
    required this.remote,
    required this.encryption,
    required this.parseManifest,
    required this.identity,
    required this.wallet,
    this.deriveEncryptionKey =
        const DeriveKeychainManifestEncryptionKeyUsecase(),
  });

  Future<KeychainManifestRemoteImportResult> execute() async {
    try {
      final source = await wallet.deriveDefaultWallet();
      final signer = KeychainManifestBackupSigner(
        publicKeyHex: identity.deriveWalletManifestPublicKeyFromXprv(
          source.xprvBase58,
        ),
        signHashHex: (hash) => identity.signWalletManifestHashFromXprv(
          xprvBase58: source.xprvBase58,
          messageHashHex: hash,
        ),
      );
      final remoteBackup = await remote.fetch(signer);
      final ciphertext = remoteBackup.ciphertext;
      if (ciphertext == null) {
        return const KeychainManifestRemoteImportResult.absent();
      }
      final key = deriveEncryptionKey.execute(
        xprvBase58: source.xprvBase58,
        expectedParentFingerprint: source.parentFingerprint,
      );
      final snapshot = encryption.decryptSnapshot(
        ciphertext: ciphertext,
        key: key,
      );
      final plan = parseManifest.executeFile(
        snapshot.manifestFile,
        expectedParentFingerprint: source.parentFingerprint,
      );
      return KeychainManifestRemoteImportResult.success(plan);
    } on KeychainManifestUnsupportedVersionException {
      return const KeychainManifestRemoteImportResult.newerVersion();
    } on KeychainManifestEntryConflictException {
      return const KeychainManifestRemoteImportResult.conflict();
    } on KeychainManifestRemoteException catch (error) {
      return switch (error.reason) {
        KeychainManifestRemoteFailureReason.unavailable ||
        KeychainManifestRemoteFailureReason.headConflict =>
          const KeychainManifestRemoteImportResult.unavailable(),
        KeychainManifestRemoteFailureReason.invalid =>
          const KeychainManifestRemoteImportResult.invalid(),
        KeychainManifestRemoteFailureReason.tooLarge =>
          const KeychainManifestRemoteImportResult.tooLarge(),
      };
    } on KeychainManifestException {
      return const KeychainManifestRemoteImportResult.invalid();
    }
  }
}
