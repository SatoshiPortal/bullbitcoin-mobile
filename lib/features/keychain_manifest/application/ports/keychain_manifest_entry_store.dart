import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_entry.dart';

abstract class KeychainManifestEntryStore {
  Future<KeychainManifestWalletMaterializationRecord?>
  fetchWalletMaterializationRecordByWalletId(String walletId);

  Future<KeychainManifestWalletMaterializationRecord?>
  fetchWalletMaterializationRecordByIdentity(
    KeychainManifestWalletMaterializationIdentity identity,
  );

  Future<void> insertWalletMaterializationRecord(
    KeychainManifestWalletMaterializationRecord record,
  );

  Future<void> deleteWalletMaterializationRecordsByIdentities(
    List<KeychainManifestWalletMaterializationIdentity> identities,
  );
}
