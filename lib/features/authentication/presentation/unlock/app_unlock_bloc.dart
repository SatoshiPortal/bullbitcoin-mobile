import 'dart:async';

import 'package:bb_mobile/features/authentication/domain/authentication_model.dart';
import 'package:bb_mobile/features/authentication/domain/usecases/get_last_authentication_attempt_usecase.dart';
import 'package:bb_mobile/features/authentication/domain/usecases/is_authentication_required_usecase.dart';
import 'package:bb_mobile/features/authentication/domain/usecases/verify_authentication_usecase.dart';
import 'package:bb_mobile/features/authentication/primitives/authentication_status.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_unlock_bloc.freezed.dart';
part 'app_unlock_event.dart';
part 'app_unlock_state.dart';

class AppUnlockBloc extends Bloc<AppUnlockEvent, AppUnlockState> {
  AppUnlockBloc({
    required IsAuthenticationRequiredUsecase isAuthenticationRequiredUsecase,
    required VerifyAuthenticationUsecase verifyAuthenticationUsecase,
    required GetLastAuthenticationAttemptUsecase
    getLastAuthenticationAttemptUsecase,
    int minPinCodeLength = 4,
    int maxPinCodeLength = 8,
  }) : _isAuthenticationRequiredUsecase = isAuthenticationRequiredUsecase,
       _verifyAuthenticationUsecase = verifyAuthenticationUsecase,
       _getLastAuthenticationAttemptUsecase =
           getLastAuthenticationAttemptUsecase,
       super(
         AppUnlockState(
           keyboardNumbers: List.generate(10, (i) => i)..shuffle(),
           minPinCodeLength: minPinCodeLength,
           maxPinCodeLength: maxPinCodeLength,
         ),
       ) {
    on<AppUnlockStarted>(_onStarted);
    on<AppUnlockPinCodeNumberAdded>(_onPinCodeNumberAdded);
    on<AppUnlockPinCodeNumberRemoved>(_onPinCodeNumberRemoved);
    on<AppUnlockSubmitted>(_onSubmitted);
    on<AppUnlockCountdownTick>(_onCountdownTick);
    on<AppUnlockPinCodeObscureToggled>(_onPinCodeObscureToggled);
  }

  final IsAuthenticationRequiredUsecase _isAuthenticationRequiredUsecase;
  final VerifyAuthenticationUsecase _verifyAuthenticationUsecase;
  final GetLastAuthenticationAttemptUsecase
  _getLastAuthenticationAttemptUsecase;

  Future<void> _onStarted(
    AppUnlockStarted event,
    Emitter<AppUnlockState> emit,
  ) async {
    try {
      final isAuthenticationRequired = await _isAuthenticationRequiredUsecase
          .execute();

      if (!isAuthenticationRequired) {
        // No authentication required, go directly to success state
        emit(state.copyWith(status: AppUnlockStatus.success));
      } else {
        final lastAttempt = await _getLastAuthenticationAttemptUsecase
            .execute();
        if (lastAttempt == null) return;

        emit(
          state.copyWith(
            status: AppUnlockStatus.inProgress,
            failedAttempts: lastAttempt.attempts,
            timeoutSeconds: lastAttempt.timeout.inSeconds,
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(status: AppUnlockStatus.failure, error: e));
    }
  }

  Future<void> _onPinCodeNumberAdded(
    AppUnlockPinCodeNumberAdded event,
    Emitter<AppUnlockState> emit,
  ) async {
    if (state.pinCode.length >= state.maxPinCodeLength) {
      return;
    }

    emit(
      state.copyWith(
        pinCode: '${state.pinCode}${event.number}',
        showError: false,
      ),
    );
  }

  Future<void> _onPinCodeNumberRemoved(
    AppUnlockPinCodeNumberRemoved event,
    Emitter<AppUnlockState> emit,
  ) async {
    if (state.pinCode.isEmpty) {
      return;
    }

    emit(
      state.copyWith(
        pinCode: state.pinCode.substring(0, state.pinCode.length - 1),
      ),
    );
  }

  Future<void> _onSubmitted(
    AppUnlockSubmitted event,
    Emitter<AppUnlockState> emit,
  ) async {
    emit(state.copyWith(isVerifying: true));
    try {
      final attempt = await _verifyAuthenticationUsecase.execute(
        PinModel(value: state.pinCode),
      );

      emit(
        state.copyWith(
          status: attempt.status == AuthenticationStatus.succeed
              ? AppUnlockStatus.success
              : AppUnlockStatus.inProgress,
          isVerifying: false,
          failedAttempts: attempt.attempts,
          timeoutSeconds: attempt.timeout.inSeconds,
          pinCode: attempt.status == AuthenticationStatus.succeed
              ? state.pinCode
              : '',
          showError: attempt.status != AuthenticationStatus.succeed,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: AppUnlockStatus.failure, error: e));
    }
  }

  void _onCountdownTick(
    AppUnlockCountdownTick event,
    Emitter<AppUnlockState> emit,
  ) {
    emit(state.copyWith(timeoutSeconds: state.timeoutSeconds - 1));
  }

  void _onPinCodeObscureToggled(
    AppUnlockPinCodeObscureToggled event,
    Emitter<AppUnlockState> emit,
  ) {
    emit(state.copyWith(obscurePinCode: !state.obscurePinCode));
  }
}
