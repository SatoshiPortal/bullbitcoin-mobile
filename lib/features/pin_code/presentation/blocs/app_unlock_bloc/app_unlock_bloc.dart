import 'dart:async';

import 'package:bb_mobile/features/pin_code/domain/usecases/attempt_unlock_with_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/get_latest_unlock_attempt_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_unlock_bloc.freezed.dart';
part 'app_unlock_event.dart';
part 'app_unlock_state.dart';

class AppUnlockBloc extends Bloc<AppUnlockEvent, AppUnlockState> {
  AppUnlockBloc({
    required CheckPinCodeExistsUsecase checkPinCodeExistsUsecase,
    required GetLatestUnlockAttemptUsecase getLatestUnlockAttemptUsecase,
    required AttemptUnlockWithPinCodeUsecase attemptUnlockWithPinCodeUsecase,
    int minPinCodeLength = 4,
    int maxPinCodeLength = 8,
  }) : _checkPinCodeExistsUsecase = checkPinCodeExistsUsecase,
       _getLatestUnlockAttemptUsecase = getLatestUnlockAttemptUsecase,
       _attemptUnlockWithPinCodeUsecase = attemptUnlockWithPinCodeUsecase,
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

  final CheckPinCodeExistsUsecase _checkPinCodeExistsUsecase;
  final GetLatestUnlockAttemptUsecase _getLatestUnlockAttemptUsecase;
  final AttemptUnlockWithPinCodeUsecase _attemptUnlockWithPinCodeUsecase;

  Future<void> _onStarted(
    AppUnlockStarted event,
    Emitter<AppUnlockState> emit,
  ) async {
    try {
      final isPinCodeSet = await _checkPinCodeExistsUsecase.execute();

      if (!isPinCodeSet) {
        // No pin code exists, go directly to success state since no pin is required
        emit(state.copyWith(status: AppUnlockStatus.success));
      } else {
        final latestAttempt = await _getLatestUnlockAttemptUsecase.execute();

        emit(
          state.copyWith(
            status: AppUnlockStatus.inProgress,
            failedAttempts: latestAttempt.failedAttempts,
            timeoutSeconds: latestAttempt.timeout,
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
      final attemptResult = await _attemptUnlockWithPinCodeUsecase.execute(
        state.pinCode,
      );

      emit(
        state.copyWith(
          status: attemptResult.success
              ? AppUnlockStatus.success
              : AppUnlockStatus.inProgress,
          isVerifying: false,
          failedAttempts: attemptResult.failedAttempts,
          timeoutSeconds: attemptResult.timeout,
          pinCode: attemptResult.success ? state.pinCode : '',
          showError: !attemptResult.success,
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
