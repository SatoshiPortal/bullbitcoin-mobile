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

  /// Number of wallets actually restored (created or already present).
  int get restoredCount => walletOutcomes.where((o) => o.succeeded).length;

  /// True when nothing was restored - an empty import plan or an all-failed
  /// run. Consumers MUST NOT treat this as a plain success: `hasFailures` is
  /// false for an empty plan, so a "restored" screen with zero wallets would
  /// otherwise be shown (PR06 I-A; the sink is closed at PR22, R2-P22a).
  bool get restoredNothing => restoredCount == 0;
}
