import 'dart:async';

import 'package:primitives/primitives.dart';

import '../../domain/onboarding_failure.dart';
import '../../domain/onboarding_operations.dart';
import '../../domain/scan_onboarding_wallet_usecase.dart';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_bloc.freezed.dart';
part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({
    required CreateOnboardingWallet createWallet,
    required RecoverOnboardingWallet recoverWallet,
    required ScanOnboardingWalletUsecase scanOnboardingWalletUsecase,
  }) : _createWallet = createWallet,
       _recoverWallet = recoverWallet,
       _scanOnboardingWalletUsecase = scanOnboardingWalletUsecase,
       super(const OnboardingState()) {
    on<OnboardingCreateNewWallet>(_onCreateNewWallet);
    on<OnboardingRecoverWalletClicked>(_onRecoverWalletClicked);

    on<OnboardingGoBack>((event, emit) {
      emit(state.copyWith(step: OnboardingStep.splash));
    });
  }

  final CreateOnboardingWallet _createWallet;
  final RecoverOnboardingWallet _recoverWallet;
  final ScanOnboardingWalletUsecase _scanOnboardingWalletUsecase;

  /// Forwards transient recovery input without putting it in bloc state.
  Future<Result<bool, OnboardingFailure>> scanWallet({
    required List<String> words,
    required bip39.Language language,
    required String passphrase,
  }) {
    return _scanOnboardingWalletUsecase.execute(
      words: words,
      language: language,
      passphrase: passphrase,
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
    switch (await _createWallet()) {
      case Ok():
        emit(
          state.copyWith(onboardingStepStatus: OnboardingStepStatus.success),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            onboardingStepStatus: OnboardingStepStatus.none,
            step: OnboardingStep.splash,
            failure: failure,
          ),
        );
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
    switch (await _recoverWallet(
      mnemonicWords: event.mnemonic.words,
      language: event.mnemonic.language,
      passphrase: event.mnemonic.passphrase,
    )) {
      case Ok():
        emit(
          state.copyWith(onboardingStepStatus: OnboardingStepStatus.success),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            onboardingStepStatus: OnboardingStepStatus.none,
            step: OnboardingStep.splash,
            failure: failure,
          ),
        );
    }
  }
}
