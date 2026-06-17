import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/pin_code/pin_code_error.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/delete_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/is_pin_code_set_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/set_pin_code_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/check_backup_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pin_code_setting_bloc.freezed.dart';
part 'pin_code_setting_event.dart';
part 'pin_code_setting_state.dart';

class PinCodeSettingBloc
    extends Bloc<PinCodeSettingEvent, PinCodeSettingState> {
  PinCodeSettingBloc({
    required this._setPinCodeUsecase,
    required this._deletePinCodeUsecase,
    required this._isPinCodeSetUsecase,
    required this._checkBackupUsecase,
    int minPinCodeLength = 4,
    int maxPinCodeLength = 8,
  }) : super(
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

  Future<void> _onInitialized(
    PinCodeSettingInitialized event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    final result = await _isPinCodeSetUsecase.execute();
    switch (result) {
      case Ok(:final value):
        if (!value) {
          final hasBackup = await _checkBackupUsecase.execute();
          final status = hasBackup
              ? PinCodeSettingStatus.choose
              : PinCodeSettingStatus.backupRequired;
          emit(state.copyWith(status: status, isPinCodeSet: false));
        } else {
          emit(
            state.copyWith(
              status: PinCodeSettingStatus.unlock,
              isPinCodeSet: true,
            ),
          );
        }
      case Err(:final failure):
        emit(
          state.copyWith(
            status: PinCodeSettingStatus.failure,
            error: failure as PinCodeError,
          ),
        );
    }
  }

  final SetPinCodeUsecase _setPinCodeUsecase;
  final DeletePinCodeUsecase _deletePinCodeUsecase;
  final IsPinCodeSetUsecase _isPinCodeSetUsecase;
  final CheckBackupUsecase _checkBackupUsecase;

  Future<void> _onStarted(
    PinCodeSettingStarted event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    final result = await _isPinCodeSetUsecase.execute();
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: PinCodeSettingStatus.settings,
            isPinCodeSet: value,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            status: PinCodeSettingStatus.failure,
            error: failure as PinCodeError,
          ),
        );
    }
  }

  Future<void> _onCreatePin(
    PinCodeCreate event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    final hasBackup = await _checkBackupUsecase.execute();
    var status = PinCodeSettingStatus.choose;
    if (!hasBackup) status = PinCodeSettingStatus.backupRequired;
    emit(state.copyWith(status: status));
  }

  Future<void> _onDeletePin(
    PinCodeDelete event,
    Emitter<PinCodeSettingState> emit,
  ) async {
    final result = await _deletePinCodeUsecase.execute();
    switch (result) {
      case Ok():
        emit(
          state.copyWith(
            status: PinCodeSettingStatus.deleted,
            isPinCodeSet: false,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            status: PinCodeSettingStatus.failure,
            error: failure as PinCodeError,
          ),
        );
    }
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
    final result = await _setPinCodeUsecase.execute(state.pinCode);
    switch (result) {
      case Ok():
        emit(state.copyWith(status: PinCodeSettingStatus.success));
      case Err(:final failure):
        emit(
          state.copyWith(
            status: PinCodeSettingStatus.failure,
            error: failure as PinCodeError,
            isConfirming: false,
          ),
        );
    }
  }

  void _onPinCodeSettingPinCodeObscureToggled(
    PinCodeSettingPinCodeObscureToggled event,
    Emitter<PinCodeSettingState> emit,
  ) {
    emit(state.copyWith(obscurePinCode: !state.obscurePinCode));
  }
}
