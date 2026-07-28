import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/create_onboarding_wallets_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_bloc.freezed.dart';
part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({
    required this._createOnboardingWalletsUsecase,
    required this._completePhysicalBackupVerificationUsecase,
  }) : super(const OnboardingState()) {
    on<OnboardingCreateNewWallet>(_onCreateNewWallet);
    on<OnboardingRecoverWalletClicked>(_onRecoverWalletClicked);

    on<OnboardingGoBack>((event, emit) {
      emit(state.copyWith(step: OnboardingStep.splash));
    });
  }

  final CreateOnboardingWalletsUsecase _createOnboardingWalletsUsecase;

  final CompletePhysicalBackupVerificationUsecase
  _completePhysicalBackupVerificationUsecase;

  void _emitFailure(OnboardingFailure failure, Emitter<OnboardingState> emit) {
    emit(
      state.copyWith(
        onboardingStepStatus: OnboardingStepStatus.none,
        step: OnboardingStep.splash,
        failure: failure,
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
    emit(
      state.copyWith(
        onboardingStepStatus: OnboardingStepStatus.loading,
        step: OnboardingStep.create,
        failure: null,
      ),
    );
    switch (await _createOnboardingWalletsUsecase.execute()) {
      case Ok():
        emit(
          state.copyWith(onboardingStepStatus: OnboardingStepStatus.success),
        );
      case Err(:final failure):
        _emitFailure(failure, emit);
    }
  }

  Future<void> _onRecoverWalletClicked(
    OnboardingRecoverWalletClicked event,
    Emitter<OnboardingState> emit,
  ) async {
    // Same serialized-event guard as `_onCreateNewWallet` (#2015).
    if (state.onboardingStepStatus == OnboardingStepStatus.loading) return;
    emit(
      state.copyWith(
        onboardingStepStatus: OnboardingStepStatus.loading,
        step: OnboardingStep.recover,
        failure: null,
      ),
    );
    switch (await _createOnboardingWalletsUsecase.execute(
      mnemonicWords: event.mnemonic.words,
    )) {
      case Err(:final failure):
        _emitFailure(failure, emit);
      case Ok(:final value):
        final completed = await _completePhysicalBackupVerificationUsecase
            .execute(masterFingerprint: value.first.masterFingerprint);
        switch (completed) {
          case Ok():
            emit(
              state.copyWith(
                onboardingStepStatus: OnboardingStepStatus.success,
              ),
            );
          case Err(:final failure):
            emit(
              state.copyWith(
                onboardingStepStatus: OnboardingStepStatus.success,
                failure: failure,
              ),
            );
        }
    }
  }
}
