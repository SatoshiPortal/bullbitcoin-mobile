import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter/widgets.dart';

extension PayinBuildProblemL10n on PayinBuildProblem {
  String toTranslated(BuildContext context) => switch (this) {
    PayinBuildProblem.insufficientFunds => context.loc.exchangePayinNoFunds,
    PayinBuildProblem.feeTooLow => context.loc.exchangePayinFeeTooLow,
    PayinBuildProblem.walletBusy => context.loc.exchangePayinWalletBusy,
    PayinBuildProblem.consolidationRequired =>
      context.loc.exchangePayinConsolidationRequired,
    PayinBuildProblem.signingRefused => context.loc.exchangePayinSigningRefused,
    PayinBuildProblem.notAuthorized => context.loc.exchangePayinNotAuthorized,
    PayinBuildProblem.invalid ||
    PayinBuildProblem.unexpected => context.loc.exchangePayinBuildFailed,
  };
}

/// Why a payin was not sent. Every case says nothing left the wallet.
extension PayinProblemL10n on PayinProblem {
  String toTranslated(BuildContext context) => switch (this) {
    PayinBuildRefused(:final reason) => reason.toTranslated(context),
    PayinSendRefused(reason: PayinRefusal.nodeRejected) =>
      context.loc.exchangePayinNodeRejected,
    PayinSendRefused(reason: PayinRefusal.payjoinNotStarted) =>
      context.loc.exchangePayinPayjoinNotStarted,
    PayinSendNotSent(reason: PayinNotSentReason.deadlinePassed) =>
      context.loc.exchangePayinDeadlinePassed,
    PayinSendNotSent(reason: PayinNotSentReason.walletBusy) =>
      context.loc.exchangePayinWalletBusy,
    PayinSendNotSent(reason: PayinNotSentReason.noConnection) =>
      context.loc.exchangeErrorNetwork,
    PayinSendNotSent(reason: PayinNotSentReason.notAuthorized) =>
      context.loc.exchangePayinNotAuthorized,
  };
}
