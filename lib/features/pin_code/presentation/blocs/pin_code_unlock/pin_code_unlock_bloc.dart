// TODO: inject check pin code exists and verify pin code use cases
// If no pin code exists, go directly to success state since no pin is required
import 'package:bb_mobile/features/pin_code/domain/usecases/attempt_unlock_with_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/get_latest_unlock_attempt_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pin_code_unlock_bloc.freezed.dart';
part 'pin_code_unlock_event.dart';
part 'pin_code_unlock_state.dart';

class PinCodeUnlockBloc extends Bloc<PinCodeUnlockEvent, PinCodeUnlockState> {
  PinCodeUnlockBloc({
    required CheckPinCodeExistsUsecase checkPinCodeExistsUsecase,
    required GetLatestUnlockAttemptUseCase getLatestUnlockAttemptUseCase,
    required AttemptUnlockWithPinCodeUseCase attemptUnlockWithPinCodeUseCase,
    int minPinCodeLength = 4,
    int maxPinCodeLength = 8,
  })  : _checkPinCodeExistsUsecase = checkPinCodeExistsUsecase,
        _getLatestUnlockAttemptUseCase = getLatestUnlockAttemptUseCase,
        _attemptUnlockWithPinCodeUseCase = attemptUnlockWithPinCodeUseCase,
        super(
          PinCodeUnlockState(
            keyboardNumbers: List.generate(10, (i) => i)..shuffle(),
            minPinCodeLength: minPinCodeLength,
            maxPinCodeLength: maxPinCodeLength,
          ),
        ) {
    on<PinCodeUnlockStarted>(_onPinCodeUnlockStarted);
    on<PinCodeUnlockPinChanged>(_onPinCodeUnlockPinChanged);
    on<PinCodeUnlockSubmitted>(_onPinCodeUnlockSubmitted);
    on<PinCodeUnlockCountdownTick>(_onPinCodeUnlockCountdownTick);
  }

  final CheckPinCodeExistsUsecase _checkPinCodeExistsUsecase;
  final GetLatestUnlockAttemptUseCase _getLatestUnlockAttemptUseCase;
  final AttemptUnlockWithPinCodeUseCase _attemptUnlockWithPinCodeUseCase;

  Future<void> _onPinCodeUnlockStarted(
    PinCodeUnlockStarted event,
    Emitter<PinCodeUnlockState> emit,
  ) async {
    try {
      final isPinCodeSet = await _checkPinCodeExistsUsecase.execute();

      if (!isPinCodeSet) {
        // No pin code exists, go directly to success state since no pin is required
        emit(state.copyWith(status: PinCodeUnlockStatus.success));
      }

      final latestAttempt = await _getLatestUnlockAttemptUseCase.execute();

      emit(
        state.copyWith(
          status: PinCodeUnlockStatus.inputInProgress,
          failedAttempts: latestAttempt.failedAttempts,
          timeoutSeconds: latestAttempt.timeout,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: PinCodeUnlockStatus.failure,
          error: e,
        ),
      );
    }
  }

  Future<void> _onPinCodeUnlockPinChanged(
    PinCodeUnlockPinChanged event,
    Emitter<PinCodeUnlockState> emit,
  ) async {
    emit(
      state.copyWith(
        pinCode: event.pinCode,
      ),
    );
  }

  Future<void> _onPinCodeUnlockSubmitted(
    PinCodeUnlockSubmitted event,
    Emitter<PinCodeUnlockState> emit,
  ) async {
    emit(state.copyWith(status: PinCodeUnlockStatus.verificationInProgress));
    try {
      final attemptResult =
          await _attemptUnlockWithPinCodeUseCase.execute(state.pinCode);

      emit(
        state.copyWith(
          status: attemptResult.success
              ? PinCodeUnlockStatus.success
              : PinCodeUnlockStatus.inputInProgress,
          failedAttempts: attemptResult.failedAttempts,
          timeoutSeconds: attemptResult.timeout,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: PinCodeUnlockStatus.failure,
          error: e,
        ),
      );
    }
  }

  void _onPinCodeUnlockCountdownTick(
    PinCodeUnlockCountdownTick event,
    Emitter<PinCodeUnlockState> emit,
  ) {
    emit(state.copyWith(timeoutSeconds: state.timeoutSeconds - 1));
  }
}
