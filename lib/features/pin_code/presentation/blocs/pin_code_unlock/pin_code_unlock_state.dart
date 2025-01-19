part of 'pin_code_setting_bloc.dart';

enum PinCodeSettingStatus {
  initial,
  starting,
  inputInProgress,
  verificationInProgress,
  timeout,
  success,
  failure
}

@freezed
sealed class PinCodeSettingState with _$PinCodeSettingState {
  const factory PinCodeSettingState({
    @Default(PinCodeSettingStatus.initial) PinCodeSettingStatus status,
    @Default(4) int minPinCodeLength,
    @Default(8) int maxPinCodeLength,
    @Default('') String pinCode,
    @Default(0) int nrOfAttempts,
    @Default(0) int timeoutSeconds,
    Object? error,
  }) = _PinCodeState;
  const PinCodeSettingState._();

  bool get isValidNewPinCode =>
      newPinCode.length >= minPinCodeLength &&
      newPinCode.length <= maxPinCodeLength;

  bool get canSubmit => newPinCode == newPinCodeConfirmation;

  bool get canBackspaceOldPinCode => oldPinCode.isNotEmpty;
  bool get canBackspaceNewPinCode => newPinCode.isNotEmpty;
  bool get canBackspaceNewPinCodeConfirmation =>
      newPinCodeConfirmation.isNotEmpty;

  bool get canAddToOldPinCode => oldPinCode.length < maxPinCodeLength;
  bool get canAddToNewPinCode => newPinCode.length < maxPinCodeLength;
  bool get canAddToNewPinCodeConfirmation =>
      newPinCodeConfirmation.length < maxPinCodeLength;
}
