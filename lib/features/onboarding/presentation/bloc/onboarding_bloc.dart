import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_bloc.freezed.dart';
part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({
    required this._createDefaultWalletsUsecase,
    required this._completePhysicalBackupVerificationUsecase,
  }) : super(const OnboardingState()) {
    on<OnboardingCreateNewWallet>(_onCreateNewWallet);
    on<OnboardingRecoverWalletClicked>(_onRecoverWalletClicked);

    on<OnboardingGoBack>((event, emit) {
      emit(state.copyWith(step: OnboardingStep.splash));
    });
  }

  final CreateDefaultWalletsUsecase _createDefaultWalletsUsecase;

  final CompletePhysicalBackupVerificationUsecase
  _completePhysicalBackupVerificationUsecase;

  void _handleError(Exception error, Emitter<OnboardingState> emit) {
    log.severe(error: error, trace: StackTrace.current);
    emit(
      state.copyWith(
        onboardingStepStatus: OnboardingStepStatus.none,
        step: OnboardingStep.splash,
        failure: OnboardingUnexpectedFailure(error.toString()),
      ),
    );
  }

  Future<void> _onCreateNewWallet(
    OnboardingCreateNewWallet event,
    Emitter<OnboardingState> emit,
  ) async {
    // Bloc events are processed serially. By the time a 2nd queued event
    // dequeues, the 1st emit has already flipped the status to loading,
    // so this guard drops the duplicate (#2015).
    if (state.onboardingStepStatus == OnboardingStepStatus.loading) return;
    try {
      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.loading,
          step: OnboardingStep.create,
          failure: null,
        ),
      );
      await _createDefaultWalletsUsecase.execute();
      emit(state.copyWith(onboardingStepStatus: OnboardingStepStatus.success));
    } on Exception catch (e) {
      _handleError(e, emit);
    }
  }

  Future<void> _onRecoverWalletClicked(
    OnboardingRecoverWalletClicked event,
    Emitter<OnboardingState> emit,
  ) async {
    // Same serialized-event guard as `_onCreateNewWallet` (#2015).
    if (state.onboardingStepStatus == OnboardingStepStatus.loading) return;
    try {
      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.loading,
          step: OnboardingStep.recover,
          failure: null,
        ),
      );
      final restoredWallets = await _createDefaultWalletsUsecase.execute(
        mnemonicWords: event.mnemonic.words,
      );
      if (restoredWallets.isEmpty) {
        _handleError(Exception('No wallets were restored'), emit);
        return;
      }
      final completed = await _completePhysicalBackupVerificationUsecase
          .execute(masterFingerprint: restoredWallets.first.masterFingerprint);
      if (completed case Err(:final failure)) {
        log.severe(
          message: failure.logMessage,
          error: failure,
          trace: StackTrace.current,
        );
        emit(
          state.copyWith(
            onboardingStepStatus: OnboardingStepStatus.none,
            step: OnboardingStep.splash,
            failure: failure,
          ),
        );
        return;
      }
      emit(state.copyWith(onboardingStepStatus: OnboardingStepStatus.success));
    } on Exception catch (e) {
      _handleError(e, emit);
    }
  }
}
