import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_entry.dart';

abstract interface class KeychainManifestEntryRepository {
  Future<KeychainManifestWalletMaterializationRecord?>
  fetchWalletMaterializationRecordByWalletId(String walletId);

  /// Returns the records in unspecified order. Deterministic manifest file
  /// ordering is owned by `BuildKeychainManifestFileUsecase`; consumers that
  /// need a stable order must sort.
  Future<List<KeychainManifestWalletMaterializationRecord>>
  fetchWalletMaterializationRecordsByParentFingerprint(
    String parentFingerprint,
  );

  Future<void> insertWalletMaterializationRecord(
    KeychainManifestWalletMaterializationRecord record,
  );
}
