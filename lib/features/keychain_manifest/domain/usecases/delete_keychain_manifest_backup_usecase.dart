import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_backup_wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_remote_backup.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_backup_state_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_remote_repository.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';

final class DeleteKeychainManifestBackupUsecase {
  final KeychainManifestRemoteRepository remote;
  final KeychainManifestBackupStateRepository state;
  final NostrIdentityFacade identity;
  final KeychainManifestBackupWalletPort wallet;

  const DeleteKeychainManifestBackupUsecase({
    required this.remote,
    required this.state,
    required this.identity,
    required this.wallet,
  });

  Future<void> execute({required bool confirmed}) async {
    if (!confirmed) {
      throw KeychainManifestInvalidEntryException(
        'remote backup deletion requires explicit confirmation',
      );
    }
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
    final current = await remote.fetch(signer);
    await remote.delete(signer: signer, current: current);
    await state.clearRemoteCheckpoint();
  }
}
