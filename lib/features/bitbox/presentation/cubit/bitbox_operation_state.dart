import 'package:bb_mobile/core_deprecated/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core_deprecated/bitbox/domain/errors/bitbox_errors.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bitbox_operation_state.freezed.dart';

enum BitBoxOperationStatus {
  initial,
  scanning,
  connecting,
  processing,
  showingPairingCode,
  waitingForPassword,
  showingAddressVerification,
  success,
  error,
}

@freezed
sealed class BitBoxOperationState with _$BitBoxOperationState {
  const factory BitBoxOperationState({
    @Default(BitBoxOperationStatus.initial) BitBoxOperationStatus status,
    BitBoxDeviceEntity? connectedDevice,
    BitBoxError? error,
    dynamic result,
  }) = _BitBoxOperationState;

  const BitBoxOperationState._();

  bool get isInitial => status == BitBoxOperationStatus.initial;
  bool get isScanning => status == BitBoxOperationStatus.scanning;
  bool get isConnecting => status == BitBoxOperationStatus.connecting;
  bool get isProcessing => status == BitBoxOperationStatus.processing;
  bool get isShowingPairingCode => status == BitBoxOperationStatus.showingPairingCode;
  bool get isWaitingForPassword => status == BitBoxOperationStatus.waitingForPassword;
  bool get isShowingAddressVerification => status == BitBoxOperationStatus.showingAddressVerification;
  bool get isSuccess => status == BitBoxOperationStatus.success;
  bool get isError => status == BitBoxOperationStatus.error;
}
