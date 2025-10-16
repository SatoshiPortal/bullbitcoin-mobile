part of 'app_unlock_bloc.dart';

enum AppUnlockStatus { initial, inProgress, success, failure }

@freezed
sealed class AppUnlockState with _$AppUnlockState {
  const factory AppUnlockState({
    @Default(AppUnlockStatus.initial) AppUnlockStatus status,
    @Default(4) int minPinCodeLength,
    @Default(8) int maxPinCodeLength,
    required List<int> keyboardNumbers,
    @Default('') String pinCode,
    @Default(false) bool isVerifying,
    @Default(0) int failedAttempts,
    @Default(0) int timeoutSeconds,
    @Default(true) bool obscurePinCode,
    @Default(false) bool showError,
    Object? error,
  }) = _AppUnlockState;
  const AppUnlockState._();

  bool get canSubmit =>
      pinCode.length >= minPinCodeLength &&
      pinCode.length <= maxPinCodeLength &&
      !isVerifying;
}
