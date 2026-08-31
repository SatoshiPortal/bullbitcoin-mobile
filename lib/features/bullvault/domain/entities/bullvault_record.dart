import 'package:bb_mobile/core/utils/bip48_derivation.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';

enum BullVaultLifecycleStatus {
  pending,
  activating,
  active,
  migrating,
  cancelled,
}

final class BullVaultRecord {
  final String walletId;
  final String lineageId;
  final int vaultGeneration;
  final int mobileAccount;
  final int? birthHeight;
  final BullVaultRecoveryPackage recoveryPackage;
  final String? previousVaultId;
  final String? successorWalletId;
  final BullVaultLifecycleStatus status;
  final bool hardwareSetupComplete;
  final bool hardwareSetupDeferred;
  final Set<String> completedHardwareSignerIds;
  final bool recoveryPackageConfirmed;
  final bool mobileBackupDeferred;
  final DateTime createdAt;

  BullVaultRecord({
    required this.walletId,
    required this.lineageId,
    required this.vaultGeneration,
    required this.mobileAccount,
    required this.birthHeight,
    required this.recoveryPackage,
    this.previousVaultId,
    this.successorWalletId,
    this.status = BullVaultLifecycleStatus.active,
    this.hardwareSetupComplete = false,
    this.hardwareSetupDeferred = false,
    this.completedHardwareSignerIds = const {},
    this.recoveryPackageConfirmed = false,
    this.mobileBackupDeferred = false,
    required this.createdAt,
  }) {
    final storedBirthHeight = birthHeight;
    final everydayPath =
        recoveryPackage.policy.everydayKey.accountKey.derivationPath;
    final policyMobileAccount = Bip48Derivation.account(
      everydayPath,
      coinType: recoveryPackage.policy.network.coinType,
    );
    if (walletId.isEmpty ||
        lineageId.isEmpty ||
        vaultGeneration < 0 ||
        mobileAccount < 0 ||
        policyMobileAccount != mobileAccount ||
        (storedBirthHeight != null && storedBirthHeight <= 0) ||
        recoveryPackage.policy.lineageId != lineageId ||
        recoveryPackage.policy.vaultGeneration != vaultGeneration) {
      throw ArgumentError('BullVault requires valid persisted metadata');
    }
    if (vaultGeneration == 0 && previousVaultId != null) {
      throw ArgumentError('The first BullVault generation has no predecessor');
    }
    if (vaultGeneration > 0 &&
        previousVaultId == null &&
        recoveryPackage.policy.hasKnownOriginalSchedule) {
      throw ArgumentError('Renewed BullVaults require a predecessor');
    }
    if ((status == BullVaultLifecycleStatus.pending ||
            status == BullVaultLifecycleStatus.cancelled) &&
        successorWalletId != null) {
      throw ArgumentError('An inactive BullVault cannot have a successor');
    }
  }

  BullVaultRecord copyWith({
    String? successorWalletId,
    BullVaultLifecycleStatus? status,
    bool? hardwareSetupComplete,
    bool? hardwareSetupDeferred,
    Set<String>? completedHardwareSignerIds,
    bool? recoveryPackageConfirmed,
    bool? mobileBackupDeferred,
  }) => BullVaultRecord(
    walletId: walletId,
    lineageId: lineageId,
    vaultGeneration: vaultGeneration,
    mobileAccount: mobileAccount,
    birthHeight: birthHeight,
    recoveryPackage: recoveryPackage,
    previousVaultId: previousVaultId,
    successorWalletId: successorWalletId ?? this.successorWalletId,
    status: status ?? this.status,
    hardwareSetupComplete: hardwareSetupComplete ?? this.hardwareSetupComplete,
    hardwareSetupDeferred: hardwareSetupDeferred ?? this.hardwareSetupDeferred,
    completedHardwareSignerIds:
        completedHardwareSignerIds ?? this.completedHardwareSignerIds,
    recoveryPackageConfirmed:
        recoveryPackageConfirmed ?? this.recoveryPackageConfirmed,
    mobileBackupDeferred: mobileBackupDeferred ?? this.mobileBackupDeferred,
    createdAt: createdAt,
  );
}
