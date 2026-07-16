import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_import.dart';

enum KeychainManifestRemoteImportStatus {
  absent,
  unavailable,
  invalid,
  tooLarge,
  newerVersion,
  conflict,
  success,
}

final class KeychainManifestRemoteImportResult {
  final KeychainManifestRemoteImportStatus status;
  final KeychainManifestImportPlan? importPlan;

  const KeychainManifestRemoteImportResult._(this.status, [this.importPlan]);

  const KeychainManifestRemoteImportResult.absent()
    : this._(KeychainManifestRemoteImportStatus.absent);

  const KeychainManifestRemoteImportResult.unavailable()
    : this._(KeychainManifestRemoteImportStatus.unavailable);

  const KeychainManifestRemoteImportResult.invalid()
    : this._(KeychainManifestRemoteImportStatus.invalid);

  const KeychainManifestRemoteImportResult.tooLarge()
    : this._(KeychainManifestRemoteImportStatus.tooLarge);

  const KeychainManifestRemoteImportResult.newerVersion()
    : this._(KeychainManifestRemoteImportStatus.newerVersion);

  const KeychainManifestRemoteImportResult.conflict()
    : this._(KeychainManifestRemoteImportStatus.conflict);

  const KeychainManifestRemoteImportResult.success(
    KeychainManifestImportPlan plan,
  ) : this._(KeychainManifestRemoteImportStatus.success, plan);
}
