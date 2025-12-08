// lib/core/bitbox/domain/errors/bitbox_errors.dart
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';
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

  /// Returns the localized error message.
  String toTranslated(BuildContext context) => when(
    permissionDenied: () => context.loc.bitboxErrorPermissionDenied,
    noDevicesFound: () => context.loc.bitboxErrorNoDevicesFound,
    multipleDevicesFound: () => context.loc.bitboxErrorMultipleDevicesFound,
    deviceNotFound: () => context.loc.bitboxErrorDeviceNotFound,
    connectionTypeNotInitialized: () =>
        context.loc.bitboxErrorConnectionTypeNotInitialized,
    noActiveConnection: () => context.loc.bitboxErrorNoActiveConnection,
    deviceMismatch: () => context.loc.bitboxErrorDeviceMismatch,
    invalidMagicBytes: () => context.loc.bitboxErrorInvalidMagicBytes,
    deviceNotPaired: () => context.loc.bitboxErrorDeviceNotPaired,
    handshakeFailed: () => context.loc.bitboxErrorHandshakeFailed,
    operationTimeout: () => context.loc.bitboxErrorOperationTimeout,
    connectionFailed: () => context.loc.bitboxErrorConnectionFailed,
    invalidResponse: () => context.loc.bitboxErrorInvalidResponse,
    operationCancelled: () => context.loc.bitboxErrorOperationCancelled,
    operationFailed: (msg) => msg,
  );
}
