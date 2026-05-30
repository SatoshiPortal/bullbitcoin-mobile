import 'package:freezed_annotation/freezed_annotation.dart';

part 'trezor_operation_state.freezed.dart';

enum TrezorOperationStatus {
  initial,
  launching,
  waitingForSuite,
  processing,
  success,
  error,
}

@freezed
sealed class TrezorOperationState with _$TrezorOperationState {
  const factory TrezorOperationState({
    @Default(TrezorOperationStatus.initial) TrezorOperationStatus status,
    String? errorMessage,
    dynamic result,
  }) = _TrezorOperationState;

  const TrezorOperationState._();

  bool get isInitial => status == TrezorOperationStatus.initial;
  bool get isLaunching => status == TrezorOperationStatus.launching;
  bool get isWaiting => status == TrezorOperationStatus.waitingForSuite;
  bool get isProcessing => status == TrezorOperationStatus.processing;
  bool get isSuccess => status == TrezorOperationStatus.success;
  bool get isError => status == TrezorOperationStatus.error;
}
