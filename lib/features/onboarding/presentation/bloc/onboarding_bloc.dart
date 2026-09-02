import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/apply_pending_wizard_choices_after_wallet_creation_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:primitives/primitives.dart';

part 'onboarding_bloc.freezed.dart';
part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({
    required this._createDefaultWalletsUsecase,
    required this._completePhysicalBackupVerificationUsecase,
    required this._applyPendingWizardChoices,
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
  final ApplyPendingWizardChoicesAfterWalletCreationUsecase
  _applyPendingWizardChoices;
  Future<void> _handleError(Object error, Emitter<OnboardingState> emit) async {
    log.severe(error: error, trace: StackTrace.current);
    emit(
      state.copyWith(
        onboardingStepStatus: OnboardingStepStatus.none,
        step: OnboardingStep.splash,
        statusError: error.toString(),
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
          statusError: '',
        ),
      );
      await _createDefaultWalletsUsecase.execute();
      final choicesApplied = await _applyPendingChoicesAfterWalletCreation();
      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.success,
          dataBackupEnableFailed: !choicesApplied,
        ),
      );
    } catch (e) {
      await _handleError(e, emit);
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
          statusError: '',
        ),
      );
      await _createDefaultWalletsUsecase.execute(
        mnemonicWords: event.mnemonic.words,
      );
      final choicesApplied = await _applyPendingChoicesAfterWalletCreation();
      await _completePhysicalBackupVerificationUsecase.execute();
      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.success,
          dataBackupEnableFailed: !choicesApplied,
        ),
      );
    } catch (e) {
      await _handleError(e, emit);
    }
  }

  Future<bool> _applyPendingChoicesAfterWalletCreation() async {
    if (await _applyPendingWizardChoices.execute() case Err(:final failure)) {
      log.warning(
        'Could not apply pending wizard choices after wallet creation',
        error: failure.runtimeType,
      );
      return false;
    }
    return true;
  }
}
