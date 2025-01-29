part of 'app_unlock_bloc.dart';

enum AppUnlockStatus {
  initial,
  inputInProgress,
  verificationInProgress,
  success,
  failure
}

@freezed
sealed class AppUnlockState with _$AppUnlockState {
  const factory AppUnlockState({
    @Default(AppUnlockStatus.initial) AppUnlockStatus status,
    @Default(4) int minPinCodeLength,
    @Default(8) int maxPinCodeLength,
    required List<int> keyboardNumbers,
    @Default('') String pinCode,
    @Default(0) int failedAttempts,
    @Default(0) int timeoutSeconds,
    Object? error,
  }) = _AppUnlockState;
  const AppUnlockState._();

  bool get canSubmit =>
      pinCode.length >= minPinCodeLength &&
      pinCode.length <= maxPinCodeLength &&
      status == AppUnlockStatus.inputInProgress;
}
