import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_details.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_renew_request.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_renew_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/activate_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/cancel_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/encode_bullvault_recovery_package_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/load_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/renew_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/update_bullvault_setup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/watch_bullvault_migration_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_renewal_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class BullVaultRenewalCubit extends Cubit<BullVaultRenewalState> {
  final LoadBullVaultRenewalUsecase _loadUsecase;
  final RenewBullVaultUsecase _renewUsecase;
  final ActivateBullVaultRenewalUsecase _activateUsecase;
  final CancelBullVaultRenewalUsecase _cancelUsecase;
  final UpdateBullVaultSetupUsecase _updateSetupUsecase;
  final WatchBullVaultMigrationUsecase _watchMigrationUsecase;
  final EncodeBullVaultRecoveryPackageUsecase
  _encodeBullVaultRecoveryPackageUsecase;
  final List<StreamSubscription<Result<String?, BullVaultFailure>>>
  _migrationSubscriptions = [];

  BullVaultRenewalCubit(
    this._loadUsecase,
    this._renewUsecase,
    this._activateUsecase,
    this._cancelUsecase,
    this._updateSetupUsecase,
    this._watchMigrationUsecase,
    this._encodeBullVaultRecoveryPackageUsecase, {
    required String walletId,
  }) : super(BullVaultRenewalState(walletId: walletId));

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearFailure: true));
    final result = await _loadUsecase.execute(state.walletId);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        final renewal = value.renewal;
        if (renewal == null) {
          emit(
            state.copyWith(
              step: BullVaultRenewalStep.review,
              clearRenewal: true,
              details: value.details,
              schedule: value.details.policy.renewalSchedule,
              timeReference: value.timeReference,
              completedSignerIds: const {},
              recoveryPackageExported: false,
              recoveryPackageConfirmed: false,
              clearRecoveryPackageContent: true,
              needsInitialSetup: value.needsInitialSetup,
              isLoading: false,
            ),
          );
        } else {
          final record = renewal.replacement.record;
          emit(
            state.copyWith(
              step: _resumedStep(renewal),
              details: value.details,
              schedule: value.details.policy.renewalSchedule,
              renewal: renewal,
              completedSignerIds: record.completedHardwareSignerIds,
              recoveryPackageExported: record.recoveryPackageConfirmed,
              recoveryPackageConfirmed: record.recoveryPackageConfirmed,
              recoveryPackageContent: _encodeBullVaultRecoveryPackageUsecase
                  .execute(renewal.replacement.recoveryPackage),
              needsInitialSetup: value.needsInitialSetup,
              isLoading: false,
            ),
          );
        }
        await _watchPreviousVaults(value.details);
      case Err(:final failure):
        emit(state.copyWith(isLoading: false, failure: failure));
    }
  }

  void updateSchedule(BullVaultSchedule schedule) {
    final details = state.details;
    if (details == null ||
        !schedule.isValid(
          protection: details.policy.protection,
          includesInheritance: details.policy.inheritanceKey != null,
        )) {
      return;
    }
    emit(state.copyWith(schedule: schedule, clearFailure: true));
  }

  Future<void> renew({required String label}) async {
    final details = state.details;
    final schedule = state.schedule;
    final timeReference = state.timeReference;
    if (details == null ||
        schedule == null ||
        timeReference == null ||
        state.isRenewing) {
      return;
    }
    emit(state.copyWith(isRenewing: true, clearFailure: true));
    final renewalResult = await _renewUsecase.execute(
      BullVaultRenewRequest(
        walletId: state.walletId,
        label: label,
        schedule: schedule,
        timeReference: timeReference,
      ),
    );
    if (isClosed) return;
    switch (renewalResult) {
      case Ok(:final value):
        final record = value.replacement.record;
        emit(
          state.copyWith(
            step: BullVaultRenewalStep.recoveryPackage,
            renewal: value,
            completedSignerIds: record.completedHardwareSignerIds,
            recoveryPackageExported: record.recoveryPackageConfirmed,
            recoveryPackageConfirmed: record.recoveryPackageConfirmed,
            recoveryPackageContent: _encodeBullVaultRecoveryPackageUsecase
                .execute(value.replacement.recoveryPackage),
            isRenewing: false,
          ),
        );
      case Err(:final failure) when failure is BullVaultReviewExpiredFailure:
        emit(state.copyWith(isRenewing: false));
        await load();
        if (!isClosed && state.failure == null) {
          emit(state.copyWith(failure: failure));
        }
      case Err(:final failure):
        emit(state.copyWith(isRenewing: false, failure: failure));
    }
  }

  Future<void> completeSigner(String signerId) async {
    final renewal = state.renewal;
    if (renewal == null) return;
    final result = await _updateSetupUsecase.execute(
      walletId: renewal.replacement.wallet.id,
      completedHardwareSignerId: signerId,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            completedSignerIds: value.completedHardwareSignerIds,
            clearFailure: true,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  void continueSetup() {
    if (!state.canContinueSetup) return;
    switch (state.step) {
      case BullVaultRenewalStep.recoveryPackage:
        emit(
          state.copyWith(
            step: state.hardwareSetupComplete
                ? BullVaultRenewalStep.activation
                : BullVaultRenewalStep.hardwareSetup,
            clearFailure: true,
          ),
        );
        break;
      case BullVaultRenewalStep.hardwareSetup:
        emit(
          state.copyWith(
            step: BullVaultRenewalStep.activation,
            clearFailure: true,
          ),
        );
        break;
      case _:
        break;
    }
  }

  void backSetup() {
    switch (state.step) {
      case BullVaultRenewalStep.hardwareSetup:
        emit(
          state.copyWith(
            step: BullVaultRenewalStep.recoveryPackage,
            clearFailure: true,
          ),
        );
        break;
      case BullVaultRenewalStep.activation:
        emit(
          state.copyWith(
            step: state.requiredSignerIds.isEmpty
                ? BullVaultRenewalStep.recoveryPackage
                : BullVaultRenewalStep.hardwareSetup,
            clearFailure: true,
          ),
        );
        break;
      case _:
        break;
    }
  }

  void markRecoveryPackageExported() {
    emit(state.copyWith(recoveryPackageExported: true));
  }

  Future<void> confirmRecoveryPackage() async {
    final renewal = state.renewal;
    if (!state.recoveryPackageExported || renewal == null) return;
    final confirmed = !state.recoveryPackageConfirmed;
    final result = await _updateSetupUsecase.execute(
      walletId: renewal.replacement.wallet.id,
      recoveryPackageConfirmed: confirmed,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            recoveryPackageConfirmed: value.recoveryPackageConfirmed,
            clearFailure: true,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  Future<void> activate() async {
    final renewal = state.renewal;
    if (renewal == null || !state.canActivate) return;
    emit(state.copyWith(isActivating: true, clearFailure: true));
    final result = await _activateUsecase.execute(
      previousWalletId: renewal.previous.walletId,
      replacementWalletId: renewal.replacement.wallet.id,
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(
          state.copyWith(
            step: BullVaultRenewalStep.complete,
            isActivating: false,
            isActivated: true,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(isActivating: false, failure: failure));
    }
  }

  Future<void> cancel() async {
    final renewal = state.renewal;
    if (renewal == null || !state.canCancel) return;
    emit(state.copyWith(isCancelling: true, clearFailure: true));
    final result = await _cancelUsecase.execute(
      previousWalletId: renewal.previous.walletId,
      replacementWalletId: renewal.replacement.wallet.id,
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(
          state.copyWith(
            step: BullVaultRenewalStep.review,
            clearRenewal: true,
            completedSignerIds: const {},
            recoveryPackageExported: false,
            recoveryPackageConfirmed: false,
            clearRecoveryPackageContent: true,
            isCancelling: false,
          ),
        );
        await load();
      case Err(:final failure):
        emit(state.copyWith(isCancelling: false, failure: failure));
    }
  }

  Future<void> _watchPreviousVaults(BullVaultDetails details) async {
    for (final subscription in _migrationSubscriptions) {
      await subscription.cancel();
    }
    _migrationSubscriptions.clear();
    for (final previous in details.previousVaults) {
      final subscription = _watchMigrationUsecase
          .execute(
            previousWalletId: previous.wallet.id,
            migrationAddress: details.migrationAddress!,
          )
          .listen((result) {
            if (isClosed) return;
            switch (result) {
              case Ok(:final value):
                final transactionIds = Map.of(state.migrationTransactionIds);
                if (value == null) {
                  transactionIds.remove(previous.wallet.id);
                } else {
                  transactionIds[previous.wallet.id] = value;
                }
                emit(state.copyWith(migrationTransactionIds: transactionIds));
              case Err(:final failure):
                emit(state.copyWith(failure: failure));
            }
          });
      _migrationSubscriptions.add(subscription);
    }
  }

  static BullVaultRenewalStep _resumedStep(BullVaultRenewResult renewal) {
    final record = renewal.replacement.record;
    if (!record.recoveryPackageConfirmed) {
      return BullVaultRenewalStep.recoveryPackage;
    }
    final requiredSignerIds = {
      for (final signer in renewal.replacement.wallet.signers)
        if (signer.signer != SignerEntity.local) signer.id,
    };
    return record.completedHardwareSignerIds.containsAll(requiredSignerIds)
        ? BullVaultRenewalStep.activation
        : BullVaultRenewalStep.hardwareSetup;
  }

  @override
  Future<void> close() async {
    for (final subscription in _migrationSubscriptions) {
      await subscription.cancel();
    }
    return super.close();
  }
}
