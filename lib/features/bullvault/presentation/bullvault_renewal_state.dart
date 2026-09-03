import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_details.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_renew_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';

enum BullVaultRenewalStep {
  review,
  recoveryPackage,
  hardwareSetup,
  activation,
  complete,
}

final class BullVaultRenewalState {
  final String walletId;
  final BullVaultRenewalStep step;
  final BullVaultDetails? details;
  final BullVaultSchedule? schedule;
  final BullVaultTimeReference? timeReference;
  final BullVaultRenewResult? renewal;
  final Map<String, String> migrationTransactionIds;
  final Set<String> completedSignerIds;
  final bool recoveryPackageExported;
  final bool recoveryPackageConfirmed;
  final String? recoveryPackageContent;
  final bool isLoading;
  final bool isRenewing;
  final bool isActivating;
  final bool isCancelling;
  final bool needsInitialSetup;
  final BullVaultFailure? failure;

  const BullVaultRenewalState({
    required this.walletId,
    this.step = BullVaultRenewalStep.review,
    this.details,
    this.schedule,
    this.timeReference,
    this.renewal,
    this.migrationTransactionIds = const {},
    this.completedSignerIds = const {},
    this.recoveryPackageExported = false,
    this.recoveryPackageConfirmed = false,
    this.recoveryPackageContent,
    this.isLoading = false,
    this.isRenewing = false,
    this.isActivating = false,
    this.isCancelling = false,
    this.needsInitialSetup = false,
    this.failure,
  });

  Set<String> get requiredSignerIds => {
    if (renewal case final value?)
      for (final signer in value.replacement.wallet.signers)
        if (signer.signer == SignerEntity.remote) signer.id,
  };

  bool get hardwareSetupComplete =>
      completedSignerIds.containsAll(requiredSignerIds);

  bool get canActivate =>
      renewal != null &&
      hardwareSetupComplete &&
      recoveryPackageConfirmed &&
      !isActivating &&
      !isCancelling &&
      step != BullVaultRenewalStep.complete;

  bool get canContinueSetup => switch (step) {
    BullVaultRenewalStep.recoveryPackage =>
      recoveryPackageConfirmed && !isCancelling,
    BullVaultRenewalStep.hardwareSetup =>
      hardwareSetupComplete && !isCancelling,
    _ => false,
  };

  bool get canCancel =>
      renewal?.replacement.record.status == BullVaultLifecycleStatus.pending &&
      step != BullVaultRenewalStep.complete &&
      !isRenewing &&
      !isActivating &&
      !isCancelling;

  bool get handlesBackInternally =>
      step == BullVaultRenewalStep.hardwareSetup ||
      step == BullVaultRenewalStep.activation;

  BullVaultRenewalState copyWith({
    BullVaultRenewalStep? step,
    BullVaultDetails? details,
    BullVaultSchedule? schedule,
    BullVaultTimeReference? timeReference,
    BullVaultRenewResult? renewal,
    Map<String, String>? migrationTransactionIds,
    Set<String>? completedSignerIds,
    bool? recoveryPackageExported,
    bool? recoveryPackageConfirmed,
    String? recoveryPackageContent,
    bool? isLoading,
    bool? isRenewing,
    bool? isActivating,
    bool? isCancelling,
    bool? needsInitialSetup,
    BullVaultFailure? failure,
    bool clearRenewal = false,
    bool clearRecoveryPackageContent = false,
    bool clearFailure = false,
  }) => BullVaultRenewalState(
    walletId: walletId,
    step: step ?? this.step,
    details: details ?? this.details,
    schedule: schedule ?? this.schedule,
    timeReference: timeReference ?? this.timeReference,
    renewal: clearRenewal ? null : renewal ?? this.renewal,
    migrationTransactionIds:
        migrationTransactionIds ?? this.migrationTransactionIds,
    completedSignerIds: completedSignerIds ?? this.completedSignerIds,
    recoveryPackageExported:
        recoveryPackageExported ?? this.recoveryPackageExported,
    recoveryPackageConfirmed:
        recoveryPackageConfirmed ?? this.recoveryPackageConfirmed,
    recoveryPackageContent: clearRecoveryPackageContent
        ? null
        : recoveryPackageContent ?? this.recoveryPackageContent,
    isLoading: isLoading ?? this.isLoading,
    isRenewing: isRenewing ?? this.isRenewing,
    isActivating: isActivating ?? this.isActivating,
    isCancelling: isCancelling ?? this.isCancelling,
    needsInitialSetup: needsInitialSetup ?? this.needsInitialSetup,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}
