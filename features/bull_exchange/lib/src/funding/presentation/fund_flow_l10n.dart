import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:exchange/funding.dart';
import 'package:exchange/steps.dart';
import 'package:flutter/widgets.dart';

extension FundingRefusalL10n on FundingRefusal {
  String title(BuildContext context) => switch (this) {
    FundingRefusal.paymentOptionUnavailable =>
      context.loc.fundExchangeErrorTitleOrdPo404,
    FundingRefusal.optionNotPermitted =>
      context.loc.fundExchangeErrorTitleRcpPo404,
    FundingRefusal.sinpeNotRegistered =>
      context.loc.fundExchangeErrorTitleRcpPosinpe404,
    FundingRefusal.kycIncomplete => context.loc.fundExchangeErrorTitleOrdKyc400,
    FundingRefusal.copRequestInvalid =>
      context.loc.fundExchangeErrorTitleOrdCop400,
    FundingRefusal.sepaVirtualPaymentInactive =>
      context.loc.fundExchangeErrorTitleOrdCsrcp400,
    FundingRefusal.requestInvalid => context.loc.fundExchangeErrorTitleRcp400,
  };

  String message(BuildContext context) => switch (this) {
    FundingRefusal.paymentOptionUnavailable =>
      context.loc.fundExchangeErrorOrdPo404,
    FundingRefusal.optionNotPermitted => context.loc.fundExchangeErrorRcpPo404,
    FundingRefusal.sinpeNotRegistered =>
      context.loc.fundExchangeErrorRcpPosinpe404,
    FundingRefusal.kycIncomplete => context.loc.fundExchangeErrorOrdKyc400,
    FundingRefusal.copRequestInvalid => context.loc.fundExchangeErrorOrdCop400,
    FundingRefusal.sepaVirtualPaymentInactive =>
      context.loc.fundExchangeErrorOrdCsrcp400,
    FundingRefusal.requestInvalid => context.loc.fundExchangeErrorRcp400,
  };
}

/// Why a funding read gave nothing. [otherwise] is the screen's own message
/// for a server-side failure; a network failure always says so.
String fundReadProblemMessage(
  BuildContext context,
  ReadProblem problem, {
  required String otherwise,
}) => switch (problem) {
  ReadProblemUnreachable(isNetwork: true) =>
    context.loc.fundExchangeErrorNetwork,
  ReadProblemUnreachable(isNetwork: false) ||
  ReadProblemMissing() ||
  ReadProblemMalformed() => otherwise,
};
