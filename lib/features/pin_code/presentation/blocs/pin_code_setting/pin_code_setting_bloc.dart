import 'package:bb_mobile/features/pin_code/domain/usecases/set_pin_code_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pin_code_setting_event.dart';
part 'pin_code_setting_state.dart';
part 'pin_code_setting_bloc.freezed.dart';

class PinCodeSettingBloc
    extends Bloc<PinCodeSettingEvent, PinCodeSettingState> {
  PinCodeSettingBloc({
    required SetPinCodeUsecase setPinCodeUsecase,
    int minPinCodeLength = 4,
    int maxPinCodeLength = 8,
  })  : _setPinCodeUsecase = setPinCodeUsecase,
        super(
          PinCodeSettingState(
            choosePinKeyboardNumbers: List.generate(10, (i) => i)..shuffle(),
            confirmPinKeyboardNumbers: List.generate(10, (i) => i)..shuffle(),
            minPinCodeLength: minPinCodeLength,
            maxPinCodeLength: maxPinCodeLength,
          ),
        ) {
    on<PinCodeSettingStarted>(_onPinCodeSettingStarted);
    on<PinCodeSettingPinCodeNumberAdded>(_onPinCodeSettingPinCodeNumberAdded);
    on<PinCodeSettingPinCodeNumberRemoved>(
        _onPinCodeSettingPinCodeNumberRemoved);
    on<PinCodeSettingPinCodeConfirmationNumberAdded>(
      _onPinCodeSettingPinCodeConfirmationNumberAdded,
    );
    on<PinCodeSettingPinCodeConfirmationNumberRemoved>(
      _onPinCodeSettingPinCodeConfirmationNumberRemoved,
    );
    on<PinCodeSettingPinCodeChosen>(_onPinCodeSettingPinCodeChosen);
    on<PinCodeSettingPinCodeConfirmed>(_onPinCodeSettingConfirmed);
  }

  final SetPinCodeUsecase _setPinCodeUsecase;

  Future<void> _onPinCodeSettingStarted(
    PinCodeSettingStarted event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    emit(state.copyWith(status: PinCodeSettingStatus.choose));
  }

  Future<void> _onPinCodeSettingPinCodeNumberAdded(
    PinCodeSettingPinCodeNumberAdded event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    if (state.pinCode.length >= state.maxPinCodeLength) {
      return;
    }

    emit(
      state.copyWith(
        pinCode: state.pinCode + event.number.toString(),
      ),
    );
  }

  Future<void> _onPinCodeSettingPinCodeNumberRemoved(
    PinCodeSettingPinCodeNumberRemoved event,
    Emitter<PinCodeSettingState> emit,
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

  Future<void> _onPinCodeSettingPinCodeChosen(
    PinCodeSettingPinCodeChosen event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    emit(
      state.copyWith(
        status: PinCodeSettingStatus.confirm,
      ),
    );
  }

  Future<void> _onPinCodeSettingPinCodeConfirmationNumberAdded(
    PinCodeSettingPinCodeConfirmationNumberAdded event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    if (state.pinCodeConfirmation.length >= state.maxPinCodeLength) {
      return;
    }

    emit(
      state.copyWith(
        pinCodeConfirmation:
            state.pinCodeConfirmation + event.number.toString(),
      ),
    );
  }

  Future<void> _onPinCodeSettingPinCodeConfirmationNumberRemoved(
    PinCodeSettingPinCodeConfirmationNumberRemoved event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    if (state.pinCodeConfirmation.isEmpty) {
      return;
    }

    emit(
      state.copyWith(
        pinCodeConfirmation: state.pinCodeConfirmation.substring(
          0,
          state.pinCodeConfirmation.length - 1,
        ),
      ),
    );
  }

  Future<void> _onPinCodeSettingConfirmed(
    PinCodeSettingPinCodeConfirmed event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    emit(state.copyWith(isConfirming: true));
    try {
      await _setPinCodeUsecase.execute(state.pinCode);

      emit(state.copyWith(status: PinCodeSettingStatus.success));
    } catch (e) {
      emit(
        state.copyWith(
          status: PinCodeSettingStatus.failure,
          error: e,
        ),
      );
    }
  }
}
