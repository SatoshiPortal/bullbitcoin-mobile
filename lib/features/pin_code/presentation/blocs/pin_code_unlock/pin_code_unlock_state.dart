part of 'pin_code_unlock_bloc.dart';

enum PinCodeUnlockStatus {
  initial,
  inputInProgress,
  verificationInProgress,
  success,
  failure
}

@freezed
sealed class PinCodeUnlockState with _$PinCodeUnlockState {
  const factory PinCodeUnlockState({
    @Default(PinCodeUnlockStatus.initial) PinCodeUnlockStatus status,
    @Default(4) int minPinCodeLength,
    @Default(8) int maxPinCodeLength,
    @Default('') String pinCode,
    @Default(0) int failedAttempts,
    @Default(0) int timeoutSeconds,
    Object? error,
  }) = _PinCodeUnlockState;
  const PinCodeUnlockState._();

  bool get canAddNumber => pinCode.length < maxPinCodeLength;
  bool get canBackspace => pinCode.isNotEmpty;
  bool get canSubmit =>
      pinCode.length >= minPinCodeLength &&
      pinCode.length <= maxPinCodeLength &&
      status == PinCodeUnlockStatus.inputInProgress;
}
