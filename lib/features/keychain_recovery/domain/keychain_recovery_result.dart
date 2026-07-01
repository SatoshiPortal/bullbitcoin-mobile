import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';

enum KeychainRecoveryWalletRestoreStatus {
  created,
  alreadyPresent,
  skippedUnsupported,
  failedParentFingerprintMismatch,
  failedChildSeedFingerprintMismatch,
  failedInvalidImportPlan,
  failedWalletCreation,
  failedManifestRecord,
  failedConflict,
}

class KeychainRecoveryWalletRestoreOutcome {
  final KeychainManifestWalletMaterializationIntent intent;
  final KeychainRecoveryWalletRestoreStatus status;

  String get walletId => intent.walletId;

  const KeychainRecoveryWalletRestoreOutcome({
    required this.intent,
    required this.status,
  });

  bool get succeeded {
    return switch (status) {
      KeychainRecoveryWalletRestoreStatus.created ||
      KeychainRecoveryWalletRestoreStatus.alreadyPresent => true,
      _ => false,
    };
  }
}

class KeychainRecoveryResult {
  final List<KeychainRecoveryWalletRestoreOutcome> walletOutcomes;

  const KeychainRecoveryResult({required this.walletOutcomes});

  bool get hasFailures => walletOutcomes.any((outcome) => !outcome.succeeded);
}
