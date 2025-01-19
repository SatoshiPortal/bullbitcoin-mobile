import 'package:bb_mobile/features/pin_code/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/set_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/verify_pin_code_usecase.dart';
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

  Future<void> _onPinCodeSettingNewPinCodeChanged(
    PinCodeSettingNewPinCodeChanged event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    emit(
      state.copyWith(
        newPinCode: event.newPinCode,
      ),
    );
  }

  Future<void> _onPinCodeSettingNewPinCodeConfirmationChanged(
    PinCodeSettingNewPinCodeConfirmationChanged event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    emit(
      state.copyWith(
        newPinCodeConfirmation: event.newPinCodeConfirmation,
      ),
    );
  }

  Future<void> _onPinCodeSettingSubmitted(
    PinCodeSettingSubmitted event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    emit(state.copyWith(status: PinCodeSettingStatus.loading));
    try {
      if (state.status == PinCodeSettingStatus.changeInProgress) {
        await _setPinCodeUsecase.execute(
          state.newPinCode,
          oldPinCode: state.oldPinCode,
        );
      } else {
        await _setPinCodeUsecase.execute(state.newPinCode);
      }

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
