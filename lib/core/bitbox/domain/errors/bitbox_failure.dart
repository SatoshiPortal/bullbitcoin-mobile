import 'package:bb_mobile/core/failures/failure.dart';

sealed class BitBoxFailure extends Failure {
  const BitBoxFailure([super.logMessage]);
}

final class PermissionDeniedBitBoxFailure extends BitBoxFailure {
  const PermissionDeniedBitBoxFailure();
}

final class BluetoothUnavailableBitBoxFailure extends BitBoxFailure {
  const BluetoothUnavailableBitBoxFailure();
}

final class NoDevicesFoundBitBoxFailure extends BitBoxFailure {
  const NoDevicesFoundBitBoxFailure();
}

final class MultipleDevicesFoundBitBoxFailure extends BitBoxFailure {
  const MultipleDevicesFoundBitBoxFailure();
}

final class DeviceNotFoundBitBoxFailure extends BitBoxFailure {
  const DeviceNotFoundBitBoxFailure();
}

final class ConnectionTypeNotInitializedBitBoxFailure extends BitBoxFailure {
  const ConnectionTypeNotInitializedBitBoxFailure();
}

final class NoActiveConnectionBitBoxFailure extends BitBoxFailure {
  const NoActiveConnectionBitBoxFailure();
}

final class DeviceMismatchBitBoxFailure extends BitBoxFailure {
  const DeviceMismatchBitBoxFailure();
}

final class InvalidMagicBytesBitBoxFailure extends BitBoxFailure {
  const InvalidMagicBytesBitBoxFailure();
}

final class DeviceNotPairedBitBoxFailure extends BitBoxFailure {
  const DeviceNotPairedBitBoxFailure();
}

final class HandshakeFailedBitBoxFailure extends BitBoxFailure {
  const HandshakeFailedBitBoxFailure();
}

final class OperationTimeoutBitBoxFailure extends BitBoxFailure {
  const OperationTimeoutBitBoxFailure();
}

final class ConnectionFailedBitBoxFailure extends BitBoxFailure {
  const ConnectionFailedBitBoxFailure();
}

final class InvalidResponseBitBoxFailure extends BitBoxFailure {
  const InvalidResponseBitBoxFailure();
}

final class OperationCancelledBitBoxFailure extends BitBoxFailure {
  const OperationCancelledBitBoxFailure();
}

final class InvalidParametersBitBoxFailure extends BitBoxFailure {
  const InvalidParametersBitBoxFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI —
/// the presentation extension returns the shared generic string.
final class BitBoxUnexpectedFailure extends BitBoxFailure {
  const BitBoxUnexpectedFailure([super.logMessage]);
}
