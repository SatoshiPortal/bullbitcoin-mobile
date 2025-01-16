import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pin_code_event.dart';
part 'pin_code_state.dart';
part 'pin_code_bloc.freezed.dart';

class PinCodeBloc extends Bloc<PinCodeEvent, PinCodeState> {
  PinCodeBloc({
    // TODO: add use cases to check if pin code is set, set pin code, verify pin code
  }) : super(const PinCodeState.initial()) {
    on<PinCodeSettingStarted>(_onPinCodeSettingStarted);
    on<PinCodeVerificationStarted>(_onPinCodeVerificationStarted);
  }

  Future<void> _onPinCodeSettingStarted(
    PinCodeSettingStarted event,
    Emitter<PinCodeState> emit,
  ) async {
    emit(const PinCodeState.loadingInProgress());
    try {
      // TODO: check if pin code is set and change if value
      if(true) {
        emit(const PinCodeState.creationInProgress());
      } else {
        emit(const PinCodeState.changeInProgress());
      }
    } catch (e) {
      emit(
        PinCodeState.failure(e),
      );
    }
  }
}
