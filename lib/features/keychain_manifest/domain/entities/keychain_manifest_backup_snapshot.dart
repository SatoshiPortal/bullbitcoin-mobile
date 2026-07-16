import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_file.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';

const String keychainManifestBackupContentType =
    'bullbitcoin.keychain_manifest.v1';

final class KeychainManifestBackupSnapshot {
  static const currentVersion = 1;

  final int version;
  final String contentType;
  final KeychainManifestFile manifestFile;

  KeychainManifestBackupSnapshot({
    this.version = currentVersion,
    this.contentType = keychainManifestBackupContentType,
    required this.manifestFile,
  }) {
    if (version != currentVersion) {
      throw KeychainManifestUnsupportedVersionException(version);
    }
    if (contentType != keychainManifestBackupContentType) {
      throw KeychainManifestBackupSnapshotException(
        'unsupported keychain manifest backup content type',
      );
    }
  }
}
