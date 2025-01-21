part of 'pin_code_setting_bloc.dart';

enum PinCodeSettingStatus { initial, loading, success, failure }

@freezed
sealed class PinCodeSettingState with _$PinCodeSettingState {
  const factory PinCodeSettingState({
    @Default(PinCodeSettingStatus.initial) PinCodeSettingStatus status,
    required List<int> pinCodeKeyboardNumbers,
    required List<int> pinCodeConfirmationKeyboardNumbers,
    @Default(4) int minPinCodeLength,
    @Default(8) int maxPinCodeLength,
    @Default('') String pinCode,
    @Default('') String pinCodeConfirmation,
    Object? error,
  }) = _PinCodeSettingState;
  const PinCodeSettingState._();

  bool get canAddPinCodeNumber => pinCode.length < maxPinCodeLength;
  bool get canBackspacePinCode => pinCode.isNotEmpty;
  bool get isValidPinCode =>
      pinCode.length >= minPinCodeLength && pinCode.length <= maxPinCodeLength;

  bool get canAddPinCodeConfirmationNumber =>
      pinCodeConfirmation.length < maxPinCodeLength;
  bool get canBackspacePinCodeConfirmation => pinCodeConfirmation.isNotEmpty;
  bool get canSubmit =>
      pinCode == pinCodeConfirmation && status == PinCodeSettingStatus.initial;
}
