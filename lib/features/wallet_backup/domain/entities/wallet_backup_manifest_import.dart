import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';

final class WalletBackupManifestImport {
  final KeychainManifestImportPlan plan;
  final String? definitionsPayload;
  final String? metadataPayload;

  const WalletBackupManifestImport({
    required this.plan,
    this.definitionsPayload,
    this.metadataPayload,
  });

  String get parentFingerprint => plan.parentFingerprint.hex;
}
