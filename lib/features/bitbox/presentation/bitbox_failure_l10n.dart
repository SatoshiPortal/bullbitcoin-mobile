import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [BitBoxFailure]. The `sealed` switch
/// makes a missing message a compile error. Never returns the raw [logMessage].
extension BitBoxFailureL10n on BitBoxFailure {
  String toTranslated(BuildContext context) => switch (this) {
    PermissionDeniedBitBoxFailure() => context.loc.bitboxErrorPermissionDenied,
    BluetoothUnavailableBitBoxFailure() =>
      context.loc.bitboxErrorBluetoothUnavailable,
    NoDevicesFoundBitBoxFailure() => context.loc.bitboxErrorNoDevicesFound,
    MultipleDevicesFoundBitBoxFailure() =>
      context.loc.bitboxErrorMultipleDevicesFound,
    DeviceNotFoundBitBoxFailure() => context.loc.bitboxErrorDeviceNotFound,
    ConnectionTypeNotInitializedBitBoxFailure() =>
      context.loc.bitboxErrorConnectionTypeNotInitialized,
    NoActiveConnectionBitBoxFailure() =>
      context.loc.bitboxErrorNoActiveConnection,
    DeviceMismatchBitBoxFailure() => context.loc.bitboxErrorDeviceMismatch,
    InvalidMagicBytesBitBoxFailure() =>
      context.loc.bitboxErrorInvalidMagicBytes,
    DeviceNotPairedBitBoxFailure() => context.loc.bitboxErrorDeviceNotPaired,
    HandshakeFailedBitBoxFailure() => context.loc.bitboxErrorHandshakeFailed,
    OperationTimeoutBitBoxFailure() => context.loc.bitboxErrorOperationTimeout,
    ConnectionFailedBitBoxFailure() => context.loc.bitboxErrorConnectionFailed,
    InvalidResponseBitBoxFailure() => context.loc.bitboxErrorInvalidResponse,
    OperationCancelledBitBoxFailure() =>
      context.loc.bitboxErrorOperationCancelled,
    InvalidParametersBitBoxFailure() => context.loc.bitboxErrorOperationFailed,
    BitBoxUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
