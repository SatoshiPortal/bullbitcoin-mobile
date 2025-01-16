part of 'pin_code_bloc.dart';

@freezed
sealed class PinCodeState with _$PinCodeState {
  const factory PinCodeState.initial() = PinCodeInitial;
  const factory PinCodeState.creationInProgress({
    String? pinCode,
    String? pinCodeConfirmation,
  }) = PinCodeCreationInProgress;
  const factory PinCodeState.changeInProgress({
    String? pinCode,
    String? newPinCode,
    String? newPinCodeConfirmation,
  }) = PinCodeChangeInProgress;
  const factory PinCodeState.verificationInProgress({
    String? pinCode,
  }) = PinCodeVerificationInProgress;
  const factory PinCodeState.loadingInProgress() = PinCodeLoadingInProgress;
  const factory PinCodeState.success() = PinCodeSuccess;
  const factory PinCodeState.failure(Object? e) = PinCodeFailure;
}
