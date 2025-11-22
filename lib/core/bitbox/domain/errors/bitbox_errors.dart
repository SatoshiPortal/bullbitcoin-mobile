// lib/core/bitbox/domain/errors/bitbox_errors.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bitbox_errors.freezed.dart';

@freezed
sealed class BitBoxError with _$BitBoxError {
  const factory BitBoxError.permissionDenied() = PermissionDeniedBitBoxError;
  const factory BitBoxError.noDevicesFound() = NoDevicesFoundBitBoxError;
  const factory BitBoxError.multipleDevicesFound() = MultipleDevicesFoundBitBoxError;
  const factory BitBoxError.deviceNotFound() = DeviceNotFoundBitBoxError;
  const factory BitBoxError.connectionTypeNotInitialized() = ConnectionTypeNotInitializedBitBoxError;
  const factory BitBoxError.noActiveConnection() = NoActiveConnectionBitBoxError;
  const factory BitBoxError.deviceMismatch() = DeviceMismatchBitBoxError;
  const factory BitBoxError.invalidMagicBytes() = InvalidMagicBytesBitBoxError;
  const factory BitBoxError.deviceNotPaired() = DeviceNotPairedBitBoxError;
  const factory BitBoxError.handshakeFailed() = HandshakeFailedBitBoxError;
  const factory BitBoxError.operationTimeout() = OperationTimeoutBitBoxError;
  const factory BitBoxError.connectionFailed() = ConnectionFailedBitBoxError;
  const factory BitBoxError.invalidResponse() = InvalidResponseBitBoxError;
  const factory BitBoxError.operationCancelled() = OperationCancelledBitBoxError;
  const factory BitBoxError.operationFailed({required String message}) = OperationFailedBitBoxError;

  const BitBoxError._();

  String get message => when(
    permissionDenied: () => 'USB permissions are required to connect to BitBox devices.',
    noDevicesFound: () => 'No BitBox devices found. Make sure your device is powered on and connected via USB.',
    multipleDevicesFound: () => 'Multiple BitBox devices found. Please ensure only one device is connected.',
    deviceNotFound: () => 'BitBox device not found.',
    connectionTypeNotInitialized: () => 'Connection type not initialized.',
    noActiveConnection: () => 'No active connection to BitBox device.',
    deviceMismatch: () => 'Device mismatch detected.',
    invalidMagicBytes: () => 'Invalid PSBT format detected.',
    deviceNotPaired: () => 'Device not paired. Please complete the pairing process first.',
    handshakeFailed: () => 'Failed to establish secure connection. Please try again.',
    operationTimeout: () => 'Operation timed out. Please try again.',
    connectionFailed: () => 'Failed to connect to BitBox device. Please check your connection.',
    invalidResponse: () => 'Invalid response from BitBox device. Please try again.',
    operationCancelled: () => 'Operation was cancelled. Please try again.',
    operationFailed: (msg) => msg,
  );
}
