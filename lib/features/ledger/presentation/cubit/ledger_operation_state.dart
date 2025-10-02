import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ledger_operation_state.freezed.dart';

enum LedgerOperationStatus {
  initial,
  scanning,
  connecting,
  processing,
  success,
  error,
}

@freezed
sealed class LedgerOperationState with _$LedgerOperationState {
  const factory LedgerOperationState({
    @Default(LedgerOperationStatus.initial) LedgerOperationStatus status,
    LedgerDeviceEntity? connectedDevice,
    String? errorMessage,
    dynamic result,
  }) = _LedgerOperationState;

  const LedgerOperationState._();

  bool get isInitial => status == LedgerOperationStatus.initial;
  bool get isScanning => status == LedgerOperationStatus.scanning;
  bool get isConnecting => status == LedgerOperationStatus.connecting;
  bool get isProcessing => status == LedgerOperationStatus.processing;
  bool get isSuccess => status == LedgerOperationStatus.success;
  bool get isError => status == LedgerOperationStatus.error;
}
