import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [SendFailure]. The `sealed` switch
/// makes a missing message a compile error. Never returns the raw [logMessage].
///
/// The swap-limit arms reproduce the legacy `_getSwapLimitsErrorMessage`
/// branching (below-min → above-max → generic) using the carried numeric
/// limits; `suggestInstantPayments` / `isBroadcastFailure` are read by the UI
/// for layout, not here.
extension SendFailureL10n on SendFailure {
  String toTranslated(BuildContext context) => switch (this) {
        SendInvalidPaymentRequestGenericFailure() =>
          context.loc.sendErrorInvalidAddressOrInvoice,
        SendUnsupportedQrFormatFailure() =>
          context.loc.sendErrorUnsupportedQrCodeFormat,
        SendInsufficientBalanceFailure() =>
          context.loc.sendErrorInsufficientBalanceForPayment,
        SendAmountlessInvoiceFailure() =>
          context.loc.sendErrorInvoiceMustContainAmount,
        SendExpiredInvoiceFailure() => context.loc.sendErrorInvoiceExpired,
        SendHardwareWalletSwapFailure() =>
          context.loc.sendErrorHardwareWalletCannotSwap,
        SendSwapCreationGenericFailure() =>
          context.loc.sendErrorSwapCreationFailed,
        SendSwapLimitsFailure(minLimit: final min?) =>
          context.loc.sendErrorAmountBelowMinimum(min.toString()),
        SendSwapLimitsFailure(maxLimit: final max?) =>
          context.loc.sendErrorAmountAboveMaximum(max.toString()),
        SendSwapLimitsFailure() => context.loc.sendErrorAmountBelowSwapLimits,
        SendBuildTransactionFailure() => context.loc.sendErrorBuildFailed,
        SendConfirmTransactionFailure() =>
          context.loc.sendErrorConfirmationFailed,
        SendUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
      };
}
