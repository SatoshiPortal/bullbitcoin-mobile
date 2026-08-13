import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:flutter/widgets.dart';

extension SendFailureL10n on SendFailure {
  String toTranslated(BuildContext context) => switch (this) {
    SendInvalidPaymentRequestFailure(:final isUnsupportedQr) =>
      isUnsupportedQr
          ? context.loc.sendErrorUnsupportedQrCodeFormat
          : context.loc.sendErrorInvalidAddressOrInvoice,
    SendInvoiceExpiredFailure() => context.loc.sendErrorInvoiceExpired,
    SendInvoiceAmountRequiredFailure() =>
      context.loc.sendErrorInvoiceMustContainAmount,
    SendHardwareWalletFailure() =>
      context.loc.sendErrorHardwareWalletCannotSwap,
    SendInsufficientBalanceFailure() =>
      context.loc.sendErrorInsufficientBalanceForPayment,
    SendAmountOutOfBoundsFailure(:final minimumSat?) =>
      context.loc.sendErrorAmountBelowMinimum(minimumSat.toString()),
    SendAmountOutOfBoundsFailure(:final maximumSat?) =>
      context.loc.sendErrorAmountAboveMaximum(maximumSat.toString()),
    SendAmountOutOfBoundsFailure() =>
      context.loc.sendErrorAmountBelowSwapLimits,
    SendSwapCreationFailure() => context.loc.sendErrorSwapCreationFailed,
    SendRateLimitedFailure(:final retryAfter) =>
      context.loc.swapErrorRateLimited(retryAfter?.inSeconds ?? 30),
    SendTransactionBuildFailure() => context.loc.sendErrorBuildFailed,
    SendTransactionConfirmationFailure(:final isBroadcastFailure) =>
      isBroadcastFailure
          ? context.loc.sendErrorBroadcastFailed
          : context.loc.sendErrorConfirmationFailed,
    SendUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
