import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_request.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_onboarding_snapshot.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/activate_initial_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/check_bullvault_mobile_backups_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/create_bullvault_onboarding_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/encode_bullvault_recovery_package_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/load_bullvault_onboarding_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/prepare_bullvault_time_reference_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/update_bullvault_setup_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_onboarding_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class BullVaultOnboardingCubit extends Cubit<BullVaultOnboardingState> {
  final CreateBullVaultOnboardingUsecase _createBullVaultOnboardingUsecase;
  final PrepareBullVaultTimeReferenceUsecase
  _prepareBullVaultTimeReferenceUsecase;
  final LoadBullVaultOnboardingUsecase _loadBullVaultOnboardingUsecase;
  final CheckBullVaultMobileBackupsUsecase _checkBullVaultMobileBackupsUsecase;
  final UpdateBullVaultSetupUsecase _updateBullVaultSetupUsecase;
  final ActivateInitialBullVaultUsecase _activateInitialBullVaultUsecase;
  final EncodeBullVaultRecoveryPackageUsecase
  _encodeBullVaultRecoveryPackageUsecase;
  var _reviewRequestId = 0;

  BullVaultOnboardingCubit(
    this._createBullVaultOnboardingUsecase,
    this._prepareBullVaultTimeReferenceUsecase,
    this._loadBullVaultOnboardingUsecase,
    this._checkBullVaultMobileBackupsUsecase,
    this._updateBullVaultSetupUsecase,
    this._activateInitialBullVaultUsecase,
    this._encodeBullVaultRecoveryPackageUsecase,
  ) : super(const BullVaultOnboardingState());

  Future<void> load({String? walletId}) async {
    emit(state.copyWith(isLoading: true, clearFailure: true));
    final result = await _loadBullVaultOnboardingUsecase.execute(
      walletId: walletId,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        final snapshot = value.snapshot;
        if (snapshot == null) {
          emit(state.copyWith(network: value.network, isLoading: false));
        } else {
          _restoreCompletionState(value.network, snapshot);
        }
      case Err(:final failure):
        emit(state.copyWith(isLoading: false, failure: failure));
    }
  }

  void _restoreCompletionState(
    Network network,
    BullVaultOnboardingSnapshot snapshot,
  ) {
    final result = snapshot.result;
    var backupStatus = (physical: false, recoverBull: false);
    BullVaultFailure? failure;
    switch (snapshot.mobileBackupStatus) {
      case Ok(:final value):
        backupStatus = value;
      case Err(failure: final value):
        failure = value;
      case null:
        break;
    }
    final hasMobileBackup = backupStatus.physical || backupStatus.recoverBull;
    final completedHardwareSignerIds = result.record.completedHardwareSignerIds;
    final hardwareSignerIds = result.wallet.signers
        .where((signer) => signer.signer != SignerEntity.local)
        .map((signer) => signer.id)
        .toSet();
    final hardwareSetupComplete = hardwareSignerIds.every(
      completedHardwareSignerIds.contains,
    );
    final step = !result.record.recoveryPackageConfirmed
        ? BullVaultOnboardingStep.recoveryPackage
        : !hardwareSetupComplete
        ? BullVaultOnboardingStep.hardwareSetup
        : !hasMobileBackup
        ? BullVaultOnboardingStep.mobileBackup
        : BullVaultOnboardingStep.complete;
    emit(
      state.copyWith(
        network: network,
        isLoading: false,
        isCreating: false,
        step: step,
        protection: result.policy.protection,
        protectionChoiceMade: true,
        includeInheritance: result.policy.inheritanceKey != null,
        inheritanceChoiceMade: true,
        schedule: result.policy.renewalSchedule,
        result: result,
        recoveryPackageContent: _encodeBullVaultRecoveryPackageUsecase.execute(
          result.recoveryPackage,
        ),
        completedHardwareSignerIds: completedHardwareSignerIds,
        hardwareSetupDeferred:
            result.record.hardwareSetupDeferred && !hardwareSetupComplete,
        recoveryPackageExported: result.record.recoveryPackageConfirmed,
        recoveryPackageConfirmed: result.record.recoveryPackageConfirmed,
        seedBackupVerified: backupStatus.physical,
        recoverBullBackupVerified: backupStatus.recoverBull,
        mobileBackupDeferred:
            result.record.mobileBackupDeferred && !hasMobileBackup,
        failure: failure,
      ),
    );
  }

  void selectColdDevice(SignerDeviceEntity device) => emit(
    state.copyWith(
      coldDevice: device,
      genericColdSigner: false,
      coldInput: state.coldDevice == device ? state.coldInput : '',
      clearFailure: true,
    ),
  );

  void useGenericColdSigner() => emit(
    state.copyWith(
      clearColdDevice: true,
      genericColdSigner: true,
      coldInput: '',
      clearFailure: true,
    ),
  );

  void setColdInput(String value) =>
      emit(state.copyWith(coldInput: value, clearFailure: true));

  Future<void> acceptColdKeyAndContinue(String value) async {
    if (state.step != BullVaultOnboardingStep.coldSigner) return;
    setColdInput(value);
    await next();
  }

  void setProtection(BullVaultProtection protection) {
    emit(
      state.copyWith(
        protection: protection,
        protectionChoiceMade: true,
        clearSecondColdDevice: !protection.usesTwoColdKeys,
        genericSecondColdSigner: protection.usesTwoColdKeys
            ? state.genericSecondColdSigner
            : false,
        secondColdInput: protection.usesTwoColdKeys
            ? state.secondColdInput
            : '',
        schedule: BullVaultSchedule.defaultsFor(
          protection: protection,
          includesInheritance: state.includeInheritance,
        ),
        clearTimeReference: true,
        clearFailure: true,
      ),
    );
  }

  void customizeSetup() => emit(
    state.copyWith(
      step: BullVaultOnboardingStep.protectionChoice,
      clearFailure: true,
    ),
  );

  void selectSecondColdDevice(SignerDeviceEntity device) => emit(
    state.copyWith(
      secondColdDevice: device,
      genericSecondColdSigner: false,
      secondColdInput: state.secondColdDevice == device
          ? state.secondColdInput
          : '',
      clearFailure: true,
    ),
  );

  void useGenericSecondColdSigner() => emit(
    state.copyWith(
      clearSecondColdDevice: true,
      genericSecondColdSigner: true,
      secondColdInput: '',
      clearFailure: true,
    ),
  );

  void setSecondColdInput(String value) =>
      emit(state.copyWith(secondColdInput: value, clearFailure: true));

  Future<void> acceptSecondColdKeyAndContinue(String value) async {
    if (state.step != BullVaultOnboardingStep.secondColdSigner) return;
    setSecondColdInput(value);
    await next();
  }

  void setInheritance(bool value) {
    emit(
      state.copyWith(
        includeInheritance: value,
        inheritanceChoiceMade: true,
        clearInheritanceDevice: !value,
        genericInheritanceSigner: value
            ? state.genericInheritanceSigner
            : false,
        inheritanceInput: value ? state.inheritanceInput : '',
        schedule: BullVaultSchedule.defaultsFor(
          protection: state.protection,
          includesInheritance: value,
        ),
        clearTimeReference: true,
        clearFailure: true,
      ),
    );
  }

  void selectInheritanceDevice(SignerDeviceEntity device) => emit(
    state.copyWith(
      inheritanceDevice: device,
      genericInheritanceSigner: false,
      inheritanceInput: state.inheritanceDevice == device
          ? state.inheritanceInput
          : '',
      clearFailure: true,
    ),
  );

  void useGenericInheritanceSigner() => emit(
    state.copyWith(
      clearInheritanceDevice: true,
      genericInheritanceSigner: true,
      inheritanceInput: '',
      clearFailure: true,
    ),
  );

  void setInheritanceInput(String value) =>
      emit(state.copyWith(inheritanceInput: value, clearFailure: true));

  Future<void> acceptInheritanceKeyAndContinue(String value) async {
    if (state.step != BullVaultOnboardingStep.inheritance) return;
    setInheritanceInput(value);
    await next();
  }

  void setColdYears(int value) => emit(
    state.copyWith(
      schedule: state.schedule.copyWith(coldYears: value),
      clearTimeReference: state.step != BullVaultOnboardingStep.review,
      clearFailure: true,
    ),
  );

  void setRecoveryYears(int value) => emit(
    state.copyWith(
      schedule: state.schedule.copyWith(recoveryYears: value),
      clearTimeReference: state.step != BullVaultOnboardingStep.review,
      clearFailure: true,
    ),
  );

  void setInheritanceYears(int value) => emit(
    state.copyWith(
      schedule: state.schedule.copyWith(inheritanceYears: value),
      clearTimeReference: state.step != BullVaultOnboardingStep.review,
      clearFailure: true,
    ),
  );

  Future<void> completeHardwareSigner(String signerId) async {
    final walletId = state.result?.wallet.id;
    if (walletId == null) return;
    final updated = await _updateBullVaultSetupUsecase.execute(
      walletId: walletId,
      completedHardwareSignerId: signerId,
    );
    if (isClosed) return;
    switch (updated) {
      case Ok(:final value):
        emit(
          state.copyWith(
            completedHardwareSignerIds: value.completedHardwareSignerIds,
            hardwareSetupDeferred: false,
            clearFailure: true,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  Future<void> deferHardwareSetup() async {
    final result = state.result;
    if (result == null || state.hardwareSetupComplete) return;
    final sourceStep = state.step;
    if (result.record.status == BullVaultLifecycleStatus.active) {
      final updated = await _updateBullVaultSetupUsecase.execute(
        walletId: result.wallet.id,
        hardwareSetupDeferred: true,
      );
      if (isClosed || state.step != sourceStep) return;
      if (updated case Err(:final failure)) {
        emit(state.copyWith(failure: failure));
        return;
      }
    }
    emit(
      state.copyWith(
        hardwareSetupDeferred: true,
        step: BullVaultOnboardingStep.mobileBackup,
        clearFailure: true,
      ),
    );
  }

  void confirmSeedBackup() => emit(
    state.copyWith(seedBackupVerified: true, mobileBackupDeferred: false),
  );

  Future<void> deferMobileBackup() async {
    if (!state.requiresSeedBackup || state.hasMobileBackup) return;
    final result = state.result!;
    final sourceStep = state.step;
    if (result.record.status == BullVaultLifecycleStatus.active) {
      final updated = await _updateBullVaultSetupUsecase.execute(
        walletId: result.wallet.id,
        mobileBackupDeferred: true,
      );
      if (isClosed || state.step != sourceStep) return;
      if (updated case Err(:final failure)) {
        emit(state.copyWith(failure: failure));
        return;
      }
    }
    emit(
      state.copyWith(
        mobileBackupDeferred: true,
        step: BullVaultOnboardingStep.complete,
        clearFailure: true,
      ),
    );
  }

  Future<void> refreshMobileBackupStatus() async {
    final result = state.result;
    if (result == null) return;
    final statusResult = await _checkBullVaultMobileBackupsUsecase.execute(
      result.policy.everydayKey.accountKey.masterFingerprint,
    );
    if (isClosed) return;
    switch (statusResult) {
      case Ok(:final value):
        emit(
          state.copyWith(
            seedBackupVerified: value.physical,
            recoverBullBackupVerified: value.recoverBull,
            mobileBackupDeferred: value.physical || value.recoverBull
                ? false
                : state.mobileBackupDeferred,
            clearFailure: true,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  void markRecoveryPackageExported() =>
      emit(state.copyWith(recoveryPackageExported: true));

  Future<void> confirmRecoveryPackage() async {
    final walletId = state.result?.wallet.id;
    if (walletId == null || !state.recoveryPackageExported) return;
    final updated = await _updateBullVaultSetupUsecase.execute(
      walletId: walletId,
      recoveryPackageConfirmed: true,
    );
    if (isClosed) return;
    switch (updated) {
      case Ok():
        emit(
          state.copyWith(recoveryPackageConfirmed: true, clearFailure: true),
        );
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  Future<bool> activate() async {
    final result = state.result;
    if (!state.canOpenWallet || result == null || state.isActivating) {
      return false;
    }
    if (result.record.status == BullVaultLifecycleStatus.active) {
      emit(state.copyWith(isActivating: true, clearFailure: true));
      final updated = await _updateBullVaultSetupUsecase.execute(
        walletId: result.wallet.id,
        hardwareSetupDeferred: state.hardwareSetupDeferred,
        mobileBackupDeferred: state.mobileBackupDeferred,
      );
      if (isClosed) return false;
      return switch (updated) {
        Ok() => true,
        Err(:final failure) => () {
          emit(state.copyWith(isActivating: false, failure: failure));
          return false;
        }(),
      };
    }
    emit(state.copyWith(isActivating: true, clearFailure: true));
    final activated = await _activateInitialBullVaultUsecase.execute(
      walletId: result.wallet.id,
      hardwareSetupDeferred: state.hardwareSetupDeferred,
      hasMobileBackup: state.hasMobileBackup,
      mobileBackupDeferred: state.mobileBackupDeferred,
    );
    if (isClosed) return false;
    return switch (activated) {
      Ok() => true,
      Err(:final failure) => () {
        emit(state.copyWith(isActivating: false, failure: failure));
        return false;
      }(),
    };
  }

  Future<void> next() async {
    if (!state.canContinue || state.step == BullVaultOnboardingStep.complete) {
      return;
    }
    switch (state.step) {
      case BullVaultOnboardingStep.setupChoice:
        emit(
          state.copyWith(
            step: BullVaultOnboardingStep.introduction,
            protection: BullVaultProtection.standard,
            protectionChoiceMade: true,
            includeInheritance: false,
            inheritanceChoiceMade: true,
            schedule: BullVaultSchedule.standardWithoutInheritance,
            clearSecondColdDevice: true,
            genericSecondColdSigner: false,
            secondColdInput: '',
            clearInheritanceDevice: true,
            inheritanceInput: '',
            clearTimeReference: true,
            clearFailure: true,
          ),
        );
      case BullVaultOnboardingStep.protectionChoice:
        emit(
          state.copyWith(
            step: BullVaultOnboardingStep.inheritanceChoice,
            clearFailure: true,
          ),
        );
      case BullVaultOnboardingStep.inheritanceChoice:
        emit(
          state.copyWith(
            step: BullVaultOnboardingStep.introduction,
            clearFailure: true,
          ),
        );
      case BullVaultOnboardingStep.introduction:
        emit(
          state.copyWith(
            step: BullVaultOnboardingStep.coldSigner,
            clearFailure: true,
          ),
        );
      case BullVaultOnboardingStep.coldSigner:
        if (state.usesTwoColdKeys) {
          emit(
            state.copyWith(
              step: BullVaultOnboardingStep.secondColdSigner,
              clearFailure: true,
            ),
          );
        } else if (state.includeInheritance) {
          emit(
            state.copyWith(
              step: BullVaultOnboardingStep.inheritance,
              clearFailure: true,
            ),
          );
        } else {
          await _openReview();
        }
      case BullVaultOnboardingStep.secondColdSigner:
        if (state.includeInheritance) {
          emit(
            state.copyWith(
              step: BullVaultOnboardingStep.inheritance,
              clearFailure: true,
            ),
          );
        } else {
          await _openReview();
        }
      case BullVaultOnboardingStep.inheritance:
        await _openReview();
      case BullVaultOnboardingStep.review:
        break;
      case BullVaultOnboardingStep.recoveryPackage:
        emit(
          state.copyWith(
            step: state.hardwareSetupComplete
                ? BullVaultOnboardingStep.mobileBackup
                : BullVaultOnboardingStep.hardwareSetup,
            clearFailure: true,
          ),
        );
      case BullVaultOnboardingStep.hardwareSetup:
        emit(
          state.copyWith(
            step: BullVaultOnboardingStep.mobileBackup,
            clearFailure: true,
          ),
        );
      case BullVaultOnboardingStep.mobileBackup:
        emit(
          state.copyWith(
            step: BullVaultOnboardingStep.complete,
            clearFailure: true,
          ),
        );
      case BullVaultOnboardingStep.complete:
        break;
    }
  }

  void back() {
    if (state.step == BullVaultOnboardingStep.setupChoice ||
        state.step == BullVaultOnboardingStep.recoveryPackage ||
        state.isCreating ||
        state.isActivating) {
      return;
    }
    _reviewRequestId++;
    final previousStep = switch (state.step) {
      BullVaultOnboardingStep.protectionChoice =>
        BullVaultOnboardingStep.setupChoice,
      BullVaultOnboardingStep.inheritanceChoice =>
        BullVaultOnboardingStep.protectionChoice,
      BullVaultOnboardingStep.introduction =>
        BullVaultOnboardingStep.setupChoice,
      BullVaultOnboardingStep.coldSigner =>
        BullVaultOnboardingStep.introduction,
      BullVaultOnboardingStep.secondColdSigner =>
        BullVaultOnboardingStep.coldSigner,
      BullVaultOnboardingStep.inheritance =>
        state.usesTwoColdKeys
            ? BullVaultOnboardingStep.secondColdSigner
            : BullVaultOnboardingStep.coldSigner,
      BullVaultOnboardingStep.review =>
        state.includeInheritance
            ? BullVaultOnboardingStep.inheritance
            : state.usesTwoColdKeys
            ? BullVaultOnboardingStep.secondColdSigner
            : BullVaultOnboardingStep.coldSigner,
      BullVaultOnboardingStep.hardwareSetup =>
        BullVaultOnboardingStep.recoveryPackage,
      BullVaultOnboardingStep.mobileBackup =>
        BullVaultOnboardingStep.hardwareSetup,
      BullVaultOnboardingStep.complete => BullVaultOnboardingStep.mobileBackup,
      BullVaultOnboardingStep.setupChoice ||
      BullVaultOnboardingStep.recoveryPackage => state.step,
    };
    emit(
      state.copyWith(
        step: previousStep,
        isPreparingReview: false,
        clearTimeReference: state.step == BullVaultOnboardingStep.review,
        clearFailure: true,
      ),
    );
  }

  Future<void> _openReview() async {
    final network = state.network;
    if (network == null) return;
    final sourceStep = state.step;
    final requestId = ++_reviewRequestId;
    emit(
      state.copyWith(
        isPreparingReview: true,
        clearTimeReference: sourceStep != BullVaultOnboardingStep.review,
        clearFailure: true,
      ),
    );
    final result = await _prepareBullVaultTimeReferenceUsecase.execute(
      isTestnet: network.isTestnet,
    );
    if (isClosed || requestId != _reviewRequestId || state.step != sourceStep) {
      return;
    }
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            step: BullVaultOnboardingStep.review,
            timeReference: value,
            isPreparingReview: false,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(isPreparingReview: false, failure: failure));
    }
  }

  Future<void> create({required String walletLabel}) async {
    if (state.step != BullVaultOnboardingStep.review || !state.canContinue) {
      return;
    }
    final timeReference = state.timeReference;
    if (timeReference == null) return;
    emit(state.copyWith(isCreating: true, clearFailure: true));
    final result = await _createBullVaultOnboardingUsecase.execute(
      BullVaultCreateRequest(
        label: walletLabel,
        protection: state.protection,
        cold: BullVaultSignerRequest(
          input: state.coldInput,
          device: state.coldDevice,
          genericExternal: state.genericColdSigner,
        ),
        secondCold: !state.usesTwoColdKeys
            ? null
            : BullVaultSignerRequest(
                input: state.secondColdInput,
                device: state.secondColdDevice,
                genericExternal: state.genericSecondColdSigner,
              ),
        inheritance: !state.includeInheritance
            ? null
            : BullVaultSignerRequest(
                input: state.inheritanceInput,
                device: state.inheritanceDevice,
                genericExternal: state.genericInheritanceSigner,
              ),
        schedule: state.schedule,
        timeReference: timeReference,
      ),
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        _restoreCompletionState(state.network!, value);
      case Err(:final failure) when failure is BullVaultReviewExpiredFailure:
        emit(state.copyWith(isCreating: false));
        await _openReview();
        if (!isClosed && state.step == BullVaultOnboardingStep.review) {
          emit(state.copyWith(failure: failure));
        }
      case Err(:final failure):
        emit(state.copyWith(isCreating: false, failure: failure));
    }
  }
}
