import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_entry.dart';

abstract interface class KeychainManifestEntryRepository {
  /// Returns the records sorted by BIP85 derivation path, entry id, network,
  /// then wallet id, matching the manifest file's canonical ordering.
  Future<List<KeychainManifestWalletMaterializationRecord>>
  fetchWalletMaterializationRecordsByParentFingerprint(
    String parentFingerprint,
  );

  Future<void> insertWalletMaterializationRecords(
    List<KeychainManifestWalletMaterializationRecord> records,
  );
}
