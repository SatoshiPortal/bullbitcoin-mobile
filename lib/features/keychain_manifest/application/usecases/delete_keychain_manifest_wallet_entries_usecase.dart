import 'package:bb_mobile/features/keychain_manifest/application/ports/keychain_manifest_entry_store.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_entry.dart';

class DeleteKeychainManifestWalletMaterializationsCommand {
  final List<KeychainManifestWalletMaterializationIdentity> identities;

  const DeleteKeychainManifestWalletMaterializationsCommand({
    required this.identities,
  });
}

class DeleteKeychainManifestWalletEntriesUsecase {
  final KeychainManifestEntryStore _store;

  DeleteKeychainManifestWalletEntriesUsecase({required this._store});

  Future<void> execute(
    DeleteKeychainManifestWalletMaterializationsCommand command,
  ) {
    return _store.deleteWalletMaterializationRecordsByIdentities(
      command.identities,
    );
  }
}
