import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter/widgets.dart';

/// The text of a failed read of a step. Never English-only: every case has
/// its key.
extension ReadProblemL10n on ReadProblem {
  String toTranslated(BuildContext context) => switch (this) {
    ReadProblemUnreachable(isNetwork: true) => context.loc.exchangeErrorNetwork,
    ReadProblemUnreachable() ||
    ReadProblemMissing() ||
    ReadProblemMalformed() => context.loc.exchangeStepReadFailed,
  };
}

/// The text of a write that the exchange refused, that never left the app,
/// or that a re-read showed was not applied.
extension WriteProblemL10n on WriteProblem {
  String toTranslated(BuildContext context) => switch (this) {
    WriteProblemRefused(:final reason) => reason.toTranslated(context),
    WriteProblemNotSent() => context.loc.exchangeStepNotSent,
    WriteProblemNotApplied() => context.loc.exchangeStepNotApplied,
  };
}

extension ExchangeRefusalL10n on ExchangeRefusal {
  String toTranslated(BuildContext context) => switch (orderLimit) {
    ExchangeOrderLimit(
      bound: ExchangeOrderAmountBound.minimum,
      :final amount,
      :final currency,
    ) =>
      context.loc.exchangeOrderBelowMinimum(amount.toString(), currency),
    ExchangeOrderLimit(
      bound: ExchangeOrderAmountBound.maximum,
      :final amount,
      :final currency,
    ) =>
      context.loc.exchangeOrderAboveMaximum(amount.toString(), currency),
    null =>
      payeeInactive
          ? context.loc.exchangePayeeInactive
          : context.loc.exchangeStepWriteRefused,
  };
}

/// Why the account's write gate refused a money-moving write.
extension WriteGateRefusalL10n on WriteGateRefusal {
  String toTranslated(BuildContext context) => switch (this) {
    WriteGateBusy() => context.loc.exchangeWriteGateBusy,
    WriteGateUnsettled() => context.loc.exchangeWriteGateUnsettled,
    WriteGateJournalUnreadable() =>
      context.loc.exchangeWriteGateJournalUnreadable,
  };
}
