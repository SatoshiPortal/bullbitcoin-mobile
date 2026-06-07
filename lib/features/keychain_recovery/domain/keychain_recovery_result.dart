import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

enum KeychainRecoveryWalletRestoreStatus {
  created,
  alreadyPresent,
  metadataRepaired,
  skippedUnsupported,
  failedParentFingerprintMismatch,
  failedChildSeedFingerprintMismatch,
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
