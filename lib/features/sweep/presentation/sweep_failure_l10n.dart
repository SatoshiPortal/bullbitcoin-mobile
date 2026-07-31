import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [SweepFailure]. The `sealed` switch
/// makes a missing message a compile error, and the catch-all variants return
/// the shared generic string so a dev `logMessage` never reaches the UI.
extension SweepFailureL10n on SweepFailure {
  String toTranslated(BuildContext context) => switch (this) {
    SweepNoInputsFailure() => context.loc.sweepErrorNoInputs,
    SweepNoRecipientsFailure() => context.loc.sweepErrorNoRecipients,
    SweepMissingAddressFailure() => context.loc.sweepErrorMissingAddress,
    SweepMissingAmountFailure() => context.loc.sweepErrorMissingAmount,
    SweepDuplicateAddressFailure() => context.loc.sweepErrorDuplicateAddress,
    SweepMultipleRemainderFailure() => context.loc.sweepErrorMultipleRemainder,
    SweepInvalidAddressFailure() => context.loc.sweepErrorInvalidAddress,
    SweepWrongNetworkFailure() => context.loc.sweepErrorWrongNetwork,
    SweepAmountBelowDustFailure(:final minimumSat) =>
      context.loc.sweepErrorAmountBelowDust(minimumSat.toString()),
    SweepAllocationExceedsBalanceFailure(:final overspentSat) =>
      context.loc.sweepErrorExceedsBalance(overspentSat.toString()),
    SweepNoRoomForFeeFailure() => context.loc.sweepErrorNoRoomForFee,
    SweepUnspendableInputFailure(:final count) =>
      context.loc.sweepErrorUnspendableInput(count),
    // The shortfall is the actionable part, so it leads the message whenever
    // the SDK gave us a number.
    SweepInsufficientFundsFailure(:final shortfallSat) =>
      shortfallSat == null
          ? context.loc.sweepErrorInsufficientFundsUnknown
          : context.loc.sweepErrorInsufficientFunds(shortfallSat.toString()),
    SweepFeeTooLowFailure() => context.loc.sweepErrorFeeTooLow,
    SweepFeesUnavailableFailure() => context.loc.sweepErrorFeesUnavailable,
    SweepChangeAddressesUnavailableFailure() =>
      context.loc.oopsSomethingWentWrong,
    SweepBuildFailure() => context.loc.oopsSomethingWentWrong,
    SweepSignFailure() => context.loc.sweepErrorSignFailed,
    SweepBroadcastFailure() => context.loc.sweepErrorBroadcastFailed,
    SweepUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
