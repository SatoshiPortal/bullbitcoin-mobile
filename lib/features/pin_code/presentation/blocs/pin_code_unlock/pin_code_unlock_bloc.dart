// TODO: inject check pin code exists and verify pin code use cases
// If no pin code exists, go directly to success state since no pin is required
import 'package:bb_mobile/features/pin_code/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/get_failed_unlock_attempts_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/set_failed_unlock_attempts_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/verify_pin_code_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pin_code_unlock_event.dart';
part 'pin_code_unlock_state.dart';
part 'pin_code_unlock_bloc.freezed.dart';

class PinCodeUnlockBloc extends Bloc<PinCodeUnlockEvent, PinCodeUnlockState> {
  PinCodeUnlockBloc({
    required CheckPinCodeExistsUsecase checkPinCodeExistsUsecase,
    required VerifyPinCodeUsecase verifyPinCodeUsecase,
    required GetFailedUnlockAttemptsUseCase getFailedUnlockAttemptsUseCase,
    required SetFailedUnlockAttemptsUseCase setFailedUnlockAttemptsUseCase,
    int minPinCodeLength = 4,
    int maxPinCodeLength = 8,
  })  : _checkPinCodeExistsUsecase = checkPinCodeExistsUsecase,
        _verifyPinCodeUsecase = verifyPinCodeUsecase,
        _getFailedUnlockAttemptsUseCase = getFailedUnlockAttemptsUseCase,
        _setFailedUnlockAttemptsUseCase = setFailedUnlockAttemptsUseCase,
        super(
          PinCodeUnlockState(
            minPinCodeLength: minPinCodeLength,
            maxPinCodeLength: maxPinCodeLength,
          ),
        ) {
    on<PinCodeUnlockStarted>(_onPinCodeUnlockStarted);
    on<PinCodeUnlockPinChanged>(_onPinCodeUnlockPinChanged);
  }

  final CheckPinCodeExistsUsecase _checkPinCodeExistsUsecase;
  final VerifyPinCodeUsecase _verifyPinCodeUsecase;
  final GetFailedUnlockAttemptsUseCase _getFailedUnlockAttemptsUseCase;
  final SetFailedUnlockAttemptsUseCase _setFailedUnlockAttemptsUseCase;

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

      final timeout = await _getRemainingUnlockTimeoutUsecase.execute();

      if (timeout > 0) {
        emit(state.copyWith(
          status: PinCodeUnlockStatus.timeoutInProgress,
          timeoutSeconds: timeout,
        ));
      }

      emit(state.copyWith(status: PinCodeUnlockStatus.inputInProgress));
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
    final pin = event.pinCode;
    emit(
      state.copyWith(
        pinCode: pin,
      ),
    );
  }

  Future<void> _onPinCodeUnlockSubmitted(
    PinCodeUnlockSubmitted event,
    Emitter<PinCodeUnlockState> emit,
  ) async {
    emit(state.copyWith(status: PinCodeUnlockStatus.verificationInProgress));
    try {
      final isPinVerified = await _verifyPinCodeUsecase.execute(state.pinCode);

      if (isPinVerified) {
        emit(state.copyWith(status: PinCodeUnlockStatus.success));
      } else {
        final attempts = state.nrOfAttempts + 1;
        if (attempts < 3) {
          emit(state.copyWith(
            status: PinCodeUnlockStatus.inputInProgress,
            nrOfAttempts: state.nrOfAttempts + 1,
          ));
        } else {
          emit(state.copyWith(
            status: PinCodeUnlockStatus.timeoutInProgress,
            timeoutSeconds: attempts - 2 * 30,
          ));
        }
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: PinCodeUnlockStatus.failure,
          error: e,
        ),
      );
    }
  }
}
