import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

enum KeychainRecoveryWalletRestoreStatus {
  created,
  alreadyPresent,
  requiresProductReactivation,
  skippedUnsupported,
  failedParentFingerprintMismatch,
  failedChildSeedFingerprintMismatch,
  failedInvalidImportPlan,
  failedWalletCreation,
  failedManifestRecord,
  failedConflict,
}

class KeychainRecoveryWalletIntent {
  final String entryId;
  final String reservationId;
  final String bip85DerivationPath;
  final String walletId;
  final String childSeedFingerprint;
  final Network network;
  final ScriptType scriptType;

  const KeychainRecoveryWalletIntent({
    required this.entryId,
    required this.reservationId,
    required this.bip85DerivationPath,
    required this.walletId,
    required this.childSeedFingerprint,
    required this.network,
    required this.scriptType,
  });

  String get materializationKey => '$entryId:$walletId';
}

class KeychainRecoveryWalletRestoreOutcome {
  final KeychainRecoveryWalletIntent intent;
  final KeychainRecoveryWalletRestoreStatus status;
  final String? materializedWalletId;

  const KeychainRecoveryWalletRestoreOutcome({
    required this.intent,
    required this.status,
    this.materializedWalletId,
  });

  String get walletId => materializedWalletId ?? intent.walletId;

  bool get succeeded {
    return switch (status) {
      KeychainRecoveryWalletRestoreStatus.created ||
      KeychainRecoveryWalletRestoreStatus.alreadyPresent ||
      KeychainRecoveryWalletRestoreStatus.requiresProductReactivation => true,
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

  bool get hasProductReactivationRequired {
    return walletOutcomes.any(
      (outcome) =>
          outcome.status ==
          KeychainRecoveryWalletRestoreStatus.requiresProductReactivation,
    );
  }

  List<KeychainRecoveryWalletRestoreOutcome>
  get productReactivationRequiredOutcomes {
    return walletOutcomes
        .where(
          (outcome) =>
              outcome.status ==
              KeychainRecoveryWalletRestoreStatus.requiresProductReactivation,
        )
        .toList(growable: false);
  }
}
