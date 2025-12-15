// lib/core/ledger/domain/errors/ledger_errors.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ledger_errors.freezed.dart';

@freezed
sealed class LedgerError with _$LedgerError {
  const factory LedgerError.permissionDenied() = PermissionDeniedLedgerError;
  const factory LedgerError.noDevicesFound() = NoDevicesFoundLedgerError;
  const factory LedgerError.multipleDevicesFound() = MultipleDevicesFoundLedgerError;
  const factory LedgerError.deviceNotFound() = DeviceNotFoundLedgerError;
  const factory LedgerError.connectionTypeNotInitialized() = ConnectionTypeNotInitializedLedgerError;
  const factory LedgerError.noActiveConnection() = NoActiveConnectionLedgerError;
  const factory LedgerError.deviceMismatch() = DeviceMismatchLedgerError;
  const factory LedgerError.invalidMagicBytes() = InvalidMagicBytesLedgerError;
  const factory LedgerError.operationFailed({required String message}) = OperationFailedLedgerError;

  const LedgerError._();

  String get message => when(
    permissionDenied: () => 'Bluetooth permissions are required to connect to Ledger devices.',
    noDevicesFound: () => 'No Ledger devices found. Make sure your device is powered on and has Bluetooth enabled.',
    multipleDevicesFound: () => 'Multiple Ledger devices found. Please ensure only one device is nearby.',
    deviceNotFound: () => 'Ledger device not found.',
    connectionTypeNotInitialized: () => 'Connection type not initialized.',
    noActiveConnection: () => 'No active connection to Ledger device.',
    deviceMismatch: () => 'Device mismatch detected.',
    invalidMagicBytes: () => 'Invalid PSBT format detected.',
    operationFailed: (msg) => msg,
  );
}
