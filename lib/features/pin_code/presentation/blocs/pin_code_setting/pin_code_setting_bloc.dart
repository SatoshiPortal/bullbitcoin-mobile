import 'package:bb_mobile/features/pin_code/domain/usecases/check_pin_code_exists_usecase.dart';
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
            minPinCodeLength: minPinCodeLength,
            maxPinCodeLength: maxPinCodeLength,
          ),
        ) {
    on<PinCodeSettingPinCodeChanged>(_onPinCodeSettingPinCodeChanged);
    on<PinCodeSettingPinCodeConfirmationChanged>(
      _onPinCodeSettingPinCodeConfirmationChanged,
    );
    on<PinCodeSettingSubmitted>(_onPinCodeSettingSubmitted);
  }

  final SetPinCodeUsecase _setPinCodeUsecase;

  Future<void> _onPinCodeSettingPinCodeChanged(
    PinCodeSettingPinCodeChanged event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    emit(
      state.copyWith(
        pinCode: event.pinCode,
      ),
    );
  }

  Future<void> _onPinCodeSettingPinCodeConfirmationChanged(
    PinCodeSettingPinCodeConfirmationChanged event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    emit(
      state.copyWith(
        pinCodeConfirmation: event.pinCodeConfirmation,
      ),
    );
  }

  Future<void> _onPinCodeSettingSubmitted(
    PinCodeSettingSubmitted event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    emit(state.copyWith(status: PinCodeSettingStatus.loading));
    try {
      await _setPinCodeUsecase.execute(state.pinCodeConfirmation);

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
