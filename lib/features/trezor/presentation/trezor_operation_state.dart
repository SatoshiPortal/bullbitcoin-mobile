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
abstract class TrezorOperationState<T> with _$TrezorOperationState<T> {
  const TrezorOperationState._();

  const factory TrezorOperationState({
    @Default(TrezorOperationStatus.initial) TrezorOperationStatus status,
    String? errorMessage,
    T? result,
  }) = _TrezorOperationState<T>;

  bool get isInitial => status == TrezorOperationStatus.initial;
  bool get isLaunching => status == TrezorOperationStatus.launching;
  bool get isWaiting => status == TrezorOperationStatus.waitingForSuite;
  bool get isProcessing => status == TrezorOperationStatus.processing;
  bool get isSuccess => status == TrezorOperationStatus.success;
  bool get isError => status == TrezorOperationStatus.error;
}
