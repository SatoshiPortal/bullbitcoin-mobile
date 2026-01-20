import 'dart:async';

import 'package:bb_mobile/features/authentication/domain/authentication_model.dart';
import 'package:bb_mobile/features/authentication/domain/usecases/disable_authentication_usecase.dart';
import 'package:bb_mobile/features/authentication/domain/usecases/enable_authentication.dart';
import 'package:bb_mobile/features/authentication/domain/usecases/is_authentication_required_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pin_code_setting_bloc.freezed.dart';
part 'pin_code_setting_event.dart';
part 'pin_code_setting_state.dart';

class PinCodeSettingBloc
    extends Bloc<PinCodeSettingEvent, PinCodeSettingState> {
  PinCodeSettingBloc({
    required EnableAuthenticationUsecase enableAuthenticationUsecase,
    required DisableAuthenticationUsecase disableAuthenticationUsecase,
    required IsAuthenticationRequiredUsecase isAuthenticationRequiredUsecase,
    int minPinCodeLength = 4,
    int maxPinCodeLength = 8,
  })  : _enableAuthenticationUsecase = enableAuthenticationUsecase,
        _disableAuthenticationUsecase = disableAuthenticationUsecase,
        _isAuthenticationRequiredUsecase = isAuthenticationRequiredUsecase,
        super(
          PinCodeSettingState(
            choosePinKeyboardNumbers: List.generate(10, (i) => i)..shuffle(),
            confirmPinKeyboardNumbers: List.generate(10, (i) => i)..shuffle(),
            minPinCodeLength: minPinCodeLength,
            maxPinCodeLength: maxPinCodeLength,
          ),
        ) {
    on<PinCodeSettingInitialized>(_onInitialized);
    on<PinCodeSettingStarted>(_onStarted);
    on<PinCodeSettingPinCodeNumberAdded>(_onPinCodeNumberAdded);
    on<PinCodeSettingPinCodeNumberRemoved>(_onPinCodeNumberRemoved);
    on<PinCodeSettingPinCodeConfirmationNumberAdded>(
      _onPinCodeConfirmationNumberAdded,
    );
    on<PinCodeSettingPinCodeConfirmationNumberRemoved>(
      _onPinCodeConfirmationNumberRemoved,
    );
    on<PinCodeSettingPinCodeChosen>(_onPinCodeChosen);
    on<PinCodeSettingPinCodeConfirmed>(_onConfirmed);
    on<PinCodeSettingPinCodeObscureToggled>(
      _onPinCodeSettingPinCodeObscureToggled,
    );
    on<PinCodeCreate>(_onCreatePin);
    on<PinCodeDelete>(_onDeletePin);

    add(const PinCodeSettingInitialized());
  }

  final EnableAuthenticationUsecase _enableAuthenticationUsecase;
  final DisableAuthenticationUsecase _disableAuthenticationUsecase;
  final IsAuthenticationRequiredUsecase _isAuthenticationRequiredUsecase;

  Future<void> _onInitialized(
    PinCodeSettingInitialized event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    final isPinCodeSet = await _isAuthenticationRequiredUsecase.execute();
    if (!isPinCodeSet) {
      emit(
        state.copyWith(
          status: PinCodeSettingStatus.choose,
          isPinCodeSet: false,
        ),
      );
    } else {
      emit(
        state.copyWith(status: PinCodeSettingStatus.unlock, isPinCodeSet: true),
      );
    }
  }

  Future<void> _onStarted(
    PinCodeSettingStarted event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    final isPinCodeSet = await _isAuthenticationRequiredUsecase.execute();
    emit(
      state.copyWith(
        status: PinCodeSettingStatus.settings,
        isPinCodeSet: isPinCodeSet,
      ),
    );
  }

  Future<void> _onCreatePin(
    PinCodeCreate event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    emit(state.copyWith(status: PinCodeSettingStatus.choose));
  }

  Future<void> _onDeletePin(
    PinCodeDelete event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    await _disableAuthenticationUsecase.execute();
    emit(
      state.copyWith(status: PinCodeSettingStatus.deleted, isPinCodeSet: false),
    );
  }

  Future<void> _onPinCodeNumberAdded(
    PinCodeSettingPinCodeNumberAdded event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    if (state.pinCode.length >= state.maxPinCodeLength) {
      return;
    }

    emit(state.copyWith(pinCode: state.pinCode + event.number.toString()));
  }

  Future<void> _onPinCodeNumberRemoved(
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

  Future<void> _onPinCodeChosen(
    PinCodeSettingPinCodeChosen event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    emit(
      state.copyWith(
        status: PinCodeSettingStatus.confirm,
        showConfirmationError: false,
      ),
    );
  }

  Future<void> _onPinCodeConfirmationNumberAdded(
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
        showConfirmationError: false,
      ),
    );
  }

  Future<void> _onPinCodeConfirmationNumberRemoved(
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
        showConfirmationError: false,
      ),
    );
  }

  Future<void> _onConfirmed(
    PinCodeSettingPinCodeConfirmed event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    if (state.pinCode != state.pinCodeConfirmation) {
      emit(state.copyWith(showConfirmationError: true));
      return;
    }

    emit(state.copyWith(isConfirming: true));
    try {
      // Enable expects an AuthenticationModel; provide a PinModel.
      await _enableAuthenticationUsecase.execute(PinModel(value: state.pinCode));

      emit(state.copyWith(status: PinCodeSettingStatus.success));
    } catch (e) {
      emit(state.copyWith(status: PinCodeSettingStatus.failure, error: e));
    }
  }

  void _onPinCodeSettingPinCodeObscureToggled(
    PinCodeSettingPinCodeObscureToggled event,
    Emitter<PinCodeSettingState> emit,
  ) {
    emit(state.copyWith(obscurePinCode: !state.obscurePinCode));
  }
}
