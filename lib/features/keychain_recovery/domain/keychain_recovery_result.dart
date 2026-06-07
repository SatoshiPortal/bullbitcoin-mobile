import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';

enum KeychainRecoveryWalletRestoreStatus {
  created,
  alreadyPresent,
  metadataRepaired,
  skippedUnsupported,
  failedParentFingerprintMismatch,
  failedWalletCreation,
  failedManifestRecord,
  failedConflict,
}

class KeychainRecoveryWalletRestoreOutcome {
  final KeychainManifestWalletMaterializationIntent intent;
  final KeychainRecoveryWalletRestoreStatus status;
  final String? walletId;

  const KeychainRecoveryWalletRestoreOutcome({
    required this.intent,
    required this.status,
    this.walletId,
  });

  bool get succeeded {
    return switch (status) {
      KeychainRecoveryWalletRestoreStatus.created ||
      KeychainRecoveryWalletRestoreStatus.alreadyPresent ||
      KeychainRecoveryWalletRestoreStatus.metadataRepaired => true,
      _ => false,
    };
  }
}

class KeychainRecoveryResult {
  final List<KeychainRecoveryWalletRestoreOutcome> walletOutcomes;

  const KeychainRecoveryResult({required this.walletOutcomes});

  bool get hasFailures => walletOutcomes.any((outcome) => !outcome.succeeded);
}
