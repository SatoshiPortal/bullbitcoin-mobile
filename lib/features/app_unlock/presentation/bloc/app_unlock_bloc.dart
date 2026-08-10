import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/attempt_unlock_with_pin_code_usecase.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/get_latest_unlock_attempt_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_unlock_bloc.freezed.dart';
part 'app_unlock_event.dart';
part 'app_unlock_state.dart';

class AppUnlockBloc extends Bloc<AppUnlockEvent, AppUnlockState> {
  AppUnlockBloc({
    required this._checkPinCodeExistsUsecase,
    required this._getLatestUnlockAttemptUsecase,
    required this._attemptUnlockWithPinCodeUsecase,
    int minPinCodeLength = 4,
    int maxPinCodeLength = 8,
  }) : super(
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
    switch (await _checkPinCodeExistsUsecase.execute()) {
      case Err(:final failure):
        emit(state.copyWith(status: AppUnlockStatus.failure, failure: failure));
      case Ok(:final value) when !value:
        // No pin code exists, go directly to success state since no pin is required
        emit(state.copyWith(status: AppUnlockStatus.success));
      case Ok():
        final int failedAttempts;
        final int timeoutSeconds;
        switch (await _getLatestUnlockAttemptUsecase.execute()) {
          case Ok(:final value):
            failedAttempts = value.failedAttempts;
            timeoutSeconds = value.timeout;
          case Err():
            failedAttempts = 0;
            timeoutSeconds = 0;
        }
        emit(
          state.copyWith(
            status: AppUnlockStatus.inProgress,
            failedAttempts: failedAttempts,
            timeoutSeconds: timeoutSeconds,
          ),
        );
    }
  }

  Future<void> _onPinCodeNumberAdded(
    AppUnlockPinCodeNumberAdded event,
    Emitter<AppUnlockState> emit,
  ) async {
    // During a cooldown the dial pad is disabled in the UI; ignore digits
    // here too so no PIN accumulates through any other path.
    if (state.timeoutSeconds > 0 || state.isVerifying) {
      return;
    }
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
    if (state.pinCode.isEmpty || state.isVerifying) {
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
    // The usecase enforces the cooldown against the persisted wall clock;
    // this gate only spares a pointless round-trip.
    if (state.timeoutSeconds > 0 || state.isVerifying) {
      return;
    }
    emit(state.copyWith(isVerifying: true));
    switch (await _attemptUnlockWithPinCodeUsecase.execute(state.pinCode)) {
      case Err(:final failure):
        emit(
          state.copyWith(
            status: AppUnlockStatus.failure,
            isVerifying: false,
            failure: failure,
          ),
        );
      case Ok(:final value):
        emit(
          state.copyWith(
            status: value.success
                ? AppUnlockStatus.success
                : AppUnlockStatus.inProgress,
            isVerifying: false,
            failedAttempts: value.failedAttempts,
            timeoutSeconds: value.timeout,
            pinCode: value.success ? state.pinCode : '',
            showError: !value.success,
          ),
        );
    }
  }

  void _onCountdownTick(
    AppUnlockCountdownTick event,
    Emitter<AppUnlockState> emit,
  ) {
    if (state.timeoutSeconds > 0) {
      emit(state.copyWith(timeoutSeconds: state.timeoutSeconds - 1));
    }
  }

  void _onPinCodeObscureToggled(
    AppUnlockPinCodeObscureToggled event,
    Emitter<AppUnlockState> emit,
  ) {
    emit(state.copyWith(obscurePinCode: !state.obscurePinCode));
  }
}
