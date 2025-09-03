import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/usecases/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_bloc.freezed.dart';
part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({
    required CreateDefaultWalletsUsecase createDefaultWalletsUsecase,
    required CompletePhysicalBackupVerificationUsecase
    completePhysicalBackupVerificationUsecase,
  }) : _createDefaultWalletsUsecase = createDefaultWalletsUsecase,
       _completePhysicalBackupVerificationUsecase =
           completePhysicalBackupVerificationUsecase,
       super(const OnboardingState()) {
    on<OnboardingCreateNewWallet>(_onCreateNewWallet);
    on<OnboardingRecoverWalletClicked>(_onRecoverWalletClicked);

    on<OnboardingGoBack>((event, emit) {
      emit(state.copyWith(step: OnboardingStep.splash));
    });

    on<StartTransitioning>((event, emit) {
      emit(state.copyWith(transitioning: true));
    });

    on<EndTransitioning>((event, emit) {
      emit(state.copyWith(transitioning: false));
    });
  }

  final CreateDefaultWalletsUsecase _createDefaultWalletsUsecase;

  final CompletePhysicalBackupVerificationUsecase
  _completePhysicalBackupVerificationUsecase;
  Future<void> _handleError(String error, Emitter<OnboardingState> emit) async {
    log.severe('Error: $error');
    emit(
      state.copyWith(
        onboardingStepStatus: OnboardingStepStatus.none,
        statusError: error,
      ),
    );
  }

  Future<void> _onCreateNewWallet(
    OnboardingCreateNewWallet event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.loading,
          step: OnboardingStep.create,
        ),
      );
      await Future.delayed(const Duration(seconds: 2));

      await _createDefaultWalletsUsecase.execute();
      await Future.delayed(const Duration(seconds: 2));
      emit(state.copyWith(onboardingStepStatus: OnboardingStepStatus.success));
    } catch (e) {
      await _handleError(e.toString(), emit);
    }
  }

  Future<void> _onRecoverWalletClicked(
    OnboardingRecoverWalletClicked event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.loading,
          step: OnboardingStep.recover,
        ),
      );
      await _createDefaultWalletsUsecase.execute(
        mnemonicWords: event.mnemonic.words,
      );
      await _completePhysicalBackupVerificationUsecase.execute();
      emit(state.copyWith(onboardingStepStatus: OnboardingStepStatus.success));
    } catch (e) {
      await _handleError(e.toString(), emit);
    }
  }
}
