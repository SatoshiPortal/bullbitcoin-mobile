part of 'pin_code_setting_bloc.dart';

enum PinCodeSettingStatus { initial, loading, success, failure }

@freezed
sealed class PinCodeSettingState with _$PinCodeSettingState {
  const factory PinCodeSettingState({
    @Default(PinCodeSettingStatus.initial) PinCodeSettingStatus status,
    @Default(4) int minPinCodeLength,
    @Default(8) int maxPinCodeLength,
    @Default('') String pinCode,
    @Default('') String pinCodeConfirmation,
    Object? error,
  }) = _PinCodeState;
  const PinCodeSettingState._();

  bool get isValidPinCode =>
      newPinCode.length >= minPinCodeLength &&
      newPinCode.length <= maxPinCodeLength;

  bool get canSubmit => pinCode == pinCodeConfirmation;

  bool get canBackspacepinCode => pinCode.isNotEmpty;
  bool get canBackspacepinCodeConfirmation => pinCodeConfirmation.isNotEmpty;

  bool get canAddToPinCode => pinCode.length < maxPinCodeLength;
  bool get canAddToPinCodeConfirmation =>
      pinCodeConfirmation.length < maxPinCodeLength;
}
