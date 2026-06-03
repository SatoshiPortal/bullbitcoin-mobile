import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_entry.dart';

abstract interface class KeychainManifestEntryRepository {
  Future<KeychainManifestWalletMaterializationRecord?>
  fetchWalletMaterializationRecordByWalletId(String walletId);

  Future<List<KeychainManifestWalletMaterializationRecord>>
  fetchWalletMaterializationRecordsByParentFingerprint(
    String parentFingerprint,
  );

  Future<void> insertWalletMaterializationRecord(
    KeychainManifestWalletMaterializationRecord record,
  );
}
