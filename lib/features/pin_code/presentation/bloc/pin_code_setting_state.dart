part of 'pin_code_setting_bloc.dart';

enum PinCodeSettingStatus {
  unlock,
  settings,
  choose,
  confirm,
  success,
  failure,
  deleted,
}

@freezed
sealed class PinCodeSettingState with _$PinCodeSettingState {
  const factory PinCodeSettingState({
    @Default(PinCodeSettingStatus.unlock) PinCodeSettingStatus status,
    @Default(4) int minPinCodeLength,
    @Default(8) int maxPinCodeLength,
    required List<int> choosePinKeyboardNumbers,
    required List<int> confirmPinKeyboardNumbers,
    @Default('') String pinCode,
    @Default('') String pinCodeConfirmation,
    @Default(false) bool isConfirming,
    @Default(true) bool obscurePinCode,
    @Default(false) bool isPinCodeSet,
    Object? error,
  }) = _PinCodeSettingState;
  const PinCodeSettingState._();

  bool get isValidPinCode =>
      pinCode.length >= minPinCodeLength && pinCode.length <= maxPinCodeLength;

  bool get canConfirm => pinCode == pinCodeConfirmation && !isConfirming;
}
