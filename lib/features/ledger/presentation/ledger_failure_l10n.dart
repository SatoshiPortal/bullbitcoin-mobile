import 'package:bb_mobile/core/ledger/domain/errors/ledger_failure.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [LedgerFailure]. The `sealed` switch
/// makes a missing message a compile error. Never returns the raw `logMessage`.
extension LedgerFailureL10n on LedgerFailure {
  String toTranslated(BuildContext context) => switch (this) {
    LedgerPermissionDeniedFailure() => context.loc.ledgerErrorPermissionDenied,
    LedgerNoDevicesFoundFailure() => context.loc.ledgerErrorNoDevicesFound,
    LedgerMultipleDevicesFoundFailure() =>
      context.loc.ledgerErrorMultipleDevicesFound,
    LedgerDeviceNotFoundFailure() => context.loc.ledgerErrorDeviceNotFound,
    LedgerNoConnectionFailure() => context.loc.ledgerErrorNoConnection,
    LedgerDeviceBusyFailure() => context.loc.ledgerErrorDeviceBusy,
    LedgerDeviceMismatchFailure() => context.loc.ledgerErrorDeviceMismatch,
    LedgerInvalidPsbtFailure() => context.loc.ledgerErrorInvalidPsbt,
    LedgerRejectedByUserFailure() => context.loc.ledgerErrorRejectedByUser,
    LedgerDeviceLockedFailure() => context.loc.ledgerErrorDeviceLocked,
    LedgerBitcoinAppNotOpenFailure() =>
      context.loc.ledgerErrorBitcoinAppNotOpen,
    LedgerMissingPsbtFailure() => context.loc.ledgerErrorMissingPsbt,
    LedgerMissingAddressFailure() => context.loc.ledgerErrorMissingAddress,
    LedgerMissingDerivationPathFailure() =>
      context.loc.ledgerErrorMissingDerivationPath,
    LedgerMissingScriptTypeFailure() =>
      context.loc.ledgerErrorMissingScriptType,
    LedgerUnexpectedFailure() => context.loc.ledgerErrorUnknown,
  };
}
