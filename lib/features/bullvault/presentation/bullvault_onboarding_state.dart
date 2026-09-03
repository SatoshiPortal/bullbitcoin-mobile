import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_key_source.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';

enum BullVaultOnboardingStep {
  setupChoice,
  inheritanceChoice,
  everydaySigner,
  coldSigner,
  secondColdSigner,
  inheritance,
  mobilePassphrase,
  review,
  recoveryPackage,
  hardwareSetup,
  mobileBackup,
  complete,
}

final class BullVaultOnboardingState {
  final BullVaultOnboardingStep step;
  final BullVaultProtection protection;
  final BullVaultEverydayKeySource everydayKeySource;
  final SignerDeviceEntity? everydayDevice;
  final bool genericEverydaySigner;
  final String everydayInput;
  final bool mobilePassphraseEnabled;
  final bool passphraseFreeRecovery;
  final bool mobilePassphraseReady;
  final bool mobilePassphraseBackedUp;
  final SignerDeviceEntity? coldDevice;
  final bool genericColdSigner;
  final String coldInput;
  final SignerDeviceEntity? secondColdDevice;
  final bool genericSecondColdSigner;
  final String secondColdInput;
  final bool includeInheritance;
  final bool inheritanceChoiceMade;
  final BullVaultInheritanceKeySource inheritanceSource;
  final SignerDeviceEntity? inheritanceDevice;
  final bool genericInheritanceSigner;
  final String inheritanceInput;
  final BullVaultSchedule schedule;
  final BullVaultTimeReference? timeReference;
  final Network? network;
  final bool isLoading;
  final bool isCreating;
  final bool isPreparingReview;
  final bool isActivating;
  final Set<String> completedHardwareSignerIds;
  final bool hardwareSetupDeferred;
  final bool seedBackupVerified;
  final bool recoverBullBackupVerified;
  final bool mobileBackupDeferred;
  final bool recoveryPackageExported;
  final bool recoveryPackageConfirmed;
  final String? recoveryPackageContent;
  final BullVaultFailure? failure;
  final BullVaultCreateResult? result;

  const BullVaultOnboardingState({
    this.step = BullVaultOnboardingStep.setupChoice,
    this.protection = BullVaultProtection.standard,
    this.everydayKeySource = BullVaultEverydayKeySource.bullMobile,
    this.everydayDevice,
    this.genericEverydaySigner = false,
    this.everydayInput = '',
    this.mobilePassphraseEnabled = false,
    this.passphraseFreeRecovery = false,
    this.mobilePassphraseReady = false,
    this.mobilePassphraseBackedUp = false,
    this.coldDevice,
    this.genericColdSigner = false,
    this.coldInput = '',
    this.secondColdDevice,
    this.genericSecondColdSigner = false,
    this.secondColdInput = '',
    this.includeInheritance = false,
    this.inheritanceChoiceMade = false,
    this.inheritanceSource = BullVaultInheritanceKeySource.hardware,
    this.inheritanceDevice,
    this.genericInheritanceSigner = false,
    this.inheritanceInput = '',
    this.schedule = const BullVaultSchedule(),
    this.timeReference,
    this.network,
    this.isLoading = false,
    this.isCreating = false,
    this.isPreparingReview = false,
    this.isActivating = false,
    this.completedHardwareSignerIds = const {},
    this.hardwareSetupDeferred = false,
    this.seedBackupVerified = false,
    this.recoverBullBackupVerified = false,
    this.mobileBackupDeferred = false,
    this.recoveryPackageExported = false,
    this.recoveryPackageConfirmed = false,
    this.recoveryPackageContent,
    this.failure,
    this.result,
  });

  bool get usesTwoColdKeys => protection.usesTwoColdKeys;

  bool get isInitialChoice => step == BullVaultOnboardingStep.setupChoice;

  bool get requiresSeedBackup => result?.record.mobileAccount != null;

  int get hardwareSignerCount =>
      result?.wallet.signers
          .where((signer) => signer.signer == SignerEntity.remote)
          .length ??
      0;

  int get completedHardwareSignerCount =>
      result?.wallet.signers
          .where(
            (signer) =>
                signer.signer == SignerEntity.remote &&
                completedHardwareSignerIds.contains(signer.id),
          )
          .length ??
      0;

  bool get hardwareSetupComplete =>
      completedHardwareSignerCount == hardwareSignerCount;

  bool get hasMobileBackup => seedBackupVerified || recoverBullBackupVerified;

  bool get mobileBackupReady =>
      !requiresSeedBackup || hasMobileBackup || mobileBackupDeferred;

  bool get mandatorySetupComplete =>
      recoveryPackageExported &&
      recoveryPackageConfirmed &&
      (hardwareSignerCount == 0 ||
          hardwareSetupComplete ||
          hardwareSetupDeferred);

  bool get canOpenWallet =>
      result != null &&
      !isActivating &&
      mobileBackupReady &&
      mandatorySetupComplete;

  bool get canContinue => switch (step) {
    BullVaultOnboardingStep.setupChoice => network != null && !isLoading,
    BullVaultOnboardingStep.inheritanceChoice =>
      inheritanceChoiceMade && network != null && !isLoading,
    BullVaultOnboardingStep.everydaySigner =>
      everydayKeySource == BullVaultEverydayKeySource.bullMobile ||
          (everydayInput.trim().isNotEmpty &&
              (genericEverydaySigner || everydayDevice != null)),
    BullVaultOnboardingStep.coldSigner =>
      !isPreparingReview &&
          coldInput.trim().isNotEmpty &&
          (genericColdSigner || coldDevice != null),
    BullVaultOnboardingStep.secondColdSigner =>
      !usesTwoColdKeys ||
          (!isPreparingReview &&
              secondColdInput.trim().isNotEmpty &&
              (genericSecondColdSigner || secondColdDevice != null)),
    BullVaultOnboardingStep.inheritance =>
      !isPreparingReview &&
          (!includeInheritance ||
              ((genericInheritanceSigner || inheritanceDevice != null) &&
                  inheritanceInput.trim().isNotEmpty)),
    BullVaultOnboardingStep.mobilePassphrase =>
      !mobilePassphraseEnabled ||
          (mobilePassphraseReady && mobilePassphraseBackedUp),
    BullVaultOnboardingStep.review =>
      !isCreating &&
          timeReference != null &&
          schedule.isValid(
            protection: protection,
            includesInheritance: includeInheritance,
          ),
    BullVaultOnboardingStep.recoveryPackage => recoveryPackageConfirmed,
    BullVaultOnboardingStep.hardwareSetup =>
      hardwareSetupComplete || hardwareSetupDeferred,
    BullVaultOnboardingStep.mobileBackup => mobileBackupReady,
    BullVaultOnboardingStep.complete => true,
  };

  BullVaultOnboardingState copyWith({
    BullVaultOnboardingStep? step,
    BullVaultProtection? protection,
    BullVaultEverydayKeySource? everydayKeySource,
    SignerDeviceEntity? everydayDevice,
    bool clearEverydayDevice = false,
    bool? genericEverydaySigner,
    String? everydayInput,
    bool? mobilePassphraseEnabled,
    bool? passphraseFreeRecovery,
    bool? mobilePassphraseReady,
    bool? mobilePassphraseBackedUp,
    SignerDeviceEntity? coldDevice,
    bool clearColdDevice = false,
    bool? genericColdSigner,
    String? coldInput,
    SignerDeviceEntity? secondColdDevice,
    bool clearSecondColdDevice = false,
    bool? genericSecondColdSigner,
    String? secondColdInput,
    bool? includeInheritance,
    bool? inheritanceChoiceMade,
    BullVaultInheritanceKeySource? inheritanceSource,
    SignerDeviceEntity? inheritanceDevice,
    bool clearInheritanceDevice = false,
    bool? genericInheritanceSigner,
    String? inheritanceInput,
    BullVaultSchedule? schedule,
    BullVaultTimeReference? timeReference,
    bool clearTimeReference = false,
    Network? network,
    bool? isLoading,
    bool? isCreating,
    bool? isPreparingReview,
    bool? isActivating,
    Set<String>? completedHardwareSignerIds,
    bool? hardwareSetupDeferred,
    bool? seedBackupVerified,
    bool? recoverBullBackupVerified,
    bool? mobileBackupDeferred,
    bool? recoveryPackageExported,
    bool? recoveryPackageConfirmed,
    String? recoveryPackageContent,
    BullVaultFailure? failure,
    bool clearFailure = false,
    BullVaultCreateResult? result,
  }) => BullVaultOnboardingState(
    step: step ?? this.step,
    protection: protection ?? this.protection,
    everydayKeySource: everydayKeySource ?? this.everydayKeySource,
    everydayDevice: clearEverydayDevice
        ? null
        : everydayDevice ?? this.everydayDevice,
    genericEverydaySigner: genericEverydaySigner ?? this.genericEverydaySigner,
    everydayInput: everydayInput ?? this.everydayInput,
    mobilePassphraseEnabled:
        mobilePassphraseEnabled ?? this.mobilePassphraseEnabled,
    passphraseFreeRecovery:
        passphraseFreeRecovery ?? this.passphraseFreeRecovery,
    mobilePassphraseReady: mobilePassphraseReady ?? this.mobilePassphraseReady,
    mobilePassphraseBackedUp:
        mobilePassphraseBackedUp ?? this.mobilePassphraseBackedUp,
    coldDevice: clearColdDevice ? null : coldDevice ?? this.coldDevice,
    genericColdSigner: genericColdSigner ?? this.genericColdSigner,
    coldInput: coldInput ?? this.coldInput,
    secondColdDevice: clearSecondColdDevice
        ? null
        : secondColdDevice ?? this.secondColdDevice,
    genericSecondColdSigner:
        genericSecondColdSigner ?? this.genericSecondColdSigner,
    secondColdInput: secondColdInput ?? this.secondColdInput,
    includeInheritance: includeInheritance ?? this.includeInheritance,
    inheritanceChoiceMade: inheritanceChoiceMade ?? this.inheritanceChoiceMade,
    inheritanceSource: inheritanceSource ?? this.inheritanceSource,
    inheritanceDevice: clearInheritanceDevice
        ? null
        : inheritanceDevice ?? this.inheritanceDevice,
    genericInheritanceSigner:
        genericInheritanceSigner ?? this.genericInheritanceSigner,
    inheritanceInput: inheritanceInput ?? this.inheritanceInput,
    schedule: schedule ?? this.schedule,
    timeReference: clearTimeReference
        ? null
        : timeReference ?? this.timeReference,
    network: network ?? this.network,
    isLoading: isLoading ?? this.isLoading,
    isCreating: isCreating ?? this.isCreating,
    isPreparingReview: isPreparingReview ?? this.isPreparingReview,
    isActivating: isActivating ?? this.isActivating,
    completedHardwareSignerIds:
        completedHardwareSignerIds ?? this.completedHardwareSignerIds,
    hardwareSetupDeferred: hardwareSetupDeferred ?? this.hardwareSetupDeferred,
    seedBackupVerified: seedBackupVerified ?? this.seedBackupVerified,
    recoverBullBackupVerified:
        recoverBullBackupVerified ?? this.recoverBullBackupVerified,
    mobileBackupDeferred: mobileBackupDeferred ?? this.mobileBackupDeferred,
    recoveryPackageExported:
        recoveryPackageExported ?? this.recoveryPackageExported,
    recoveryPackageConfirmed:
        recoveryPackageConfirmed ?? this.recoveryPackageConfirmed,
    recoveryPackageContent:
        recoveryPackageContent ?? this.recoveryPackageContent,
    failure: clearFailure ? null : failure ?? this.failure,
    result: result ?? this.result,
  );
}
