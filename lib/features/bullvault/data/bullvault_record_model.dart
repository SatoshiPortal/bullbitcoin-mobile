final class BullVaultRecordModel {
  final String walletId;
  final String lineageId;
  final int vaultGeneration;
  final int mobileAccount;
  final int? birthHeight;
  final String recoveryPackage;
  final String? previousVaultId;
  final String? successorWalletId;
  final String status;
  final bool hardwareSetupComplete;
  final bool hardwareSetupDeferred;
  final List<String> completedHardwareSignerIds;
  final bool recoveryPackageConfirmed;
  final bool mobileBackupDeferred;
  final String createdAt;

  const BullVaultRecordModel({
    required this.walletId,
    required this.lineageId,
    required this.vaultGeneration,
    required this.mobileAccount,
    required this.birthHeight,
    required this.recoveryPackage,
    required this.previousVaultId,
    required this.successorWalletId,
    required this.status,
    required this.hardwareSetupComplete,
    required this.hardwareSetupDeferred,
    required this.completedHardwareSignerIds,
    required this.recoveryPackageConfirmed,
    required this.mobileBackupDeferred,
    required this.createdAt,
  });

  factory BullVaultRecordModel.fromJson(Map<String, dynamic> json) =>
      BullVaultRecordModel(
        walletId: json['walletId'] as String,
        lineageId: json['lineageId'] as String,
        vaultGeneration: json['vaultGeneration'] as int,
        mobileAccount: json['mobileAccount'] as int,
        birthHeight: json['birthHeight'] as int?,
        recoveryPackage: json['recoveryPackage'] as String,
        previousVaultId: json['previousVaultId'] as String?,
        successorWalletId: json['successorWalletId'] as String?,
        status: json['status'] as String? ?? 'active',
        hardwareSetupComplete: json['hardwareSetupComplete'] as bool? ?? false,
        hardwareSetupDeferred: json['hardwareSetupDeferred'] as bool? ?? false,
        completedHardwareSignerIds: [
          for (final id
              in json['completedHardwareSignerIds'] as List<dynamic>? ??
                  const [])
            id as String,
        ],
        recoveryPackageConfirmed:
            json['recoveryPackageConfirmed'] as bool? ?? false,
        mobileBackupDeferred: json['mobileBackupDeferred'] as bool? ?? false,
        createdAt: json['createdAt'] as String,
      );

  Map<String, dynamic> toJson() => {
    'walletId': walletId,
    'lineageId': lineageId,
    'vaultGeneration': vaultGeneration,
    'mobileAccount': mobileAccount,
    'birthHeight': birthHeight,
    'recoveryPackage': recoveryPackage,
    'previousVaultId': previousVaultId,
    'successorWalletId': successorWalletId,
    'status': status,
    'hardwareSetupComplete': hardwareSetupComplete,
    'hardwareSetupDeferred': hardwareSetupDeferred,
    'completedHardwareSignerIds': completedHardwareSignerIds,
    'recoveryPackageConfirmed': recoveryPackageConfirmed,
    'mobileBackupDeferred': mobileBackupDeferred,
    'createdAt': createdAt,
  };
}
