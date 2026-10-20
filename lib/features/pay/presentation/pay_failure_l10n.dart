import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:flutter/widgets.dart';

extension PayFailureL10n on PayFailure {
  String toTranslated(BuildContext context) => switch (this) {
    PayUnauthenticatedFailure() => context.loc.payUnauthenticatedError,
    PayBelowMinAmountFailure(:final minAmount, :final currency) =>
      context.loc.payBelowMinAmountError(_formatLimit(minAmount, currency)),
    PayAboveMaxAmountFailure(:final maxAmount, :final currency) =>
      context.loc.payAboveMaxAmountError(_formatLimit(maxAmount, currency)),
    PayDepositAddressChangedFailure() =>
      context.loc.payDepositAddressChangedError,
    PayInsufficientBalanceFailure() => context.loc.payInsufficientBalanceError,
    PayFeeBelowRelayFloorFailure() => context.loc.payErrorFeeBelowRelayFloor,
    PayFeesUnavailableFailure() => context.loc.payErrorFeesUnavailable,
    PayQuoteExpiredFailure() => context.loc.payQuoteExpiredError,
    // Never `logMessage`. This arm used to be `unexpected: (m) => m`, which put
    // BDK/LWK/Dio text straight onto the payment screen.
    PayUnexpectedFailure() => context.loc.payUnexpectedError,
  };
}

String _formatLimit(double amount, String currency) =>
    currency == 'BTC' || currency == 'LBTC'
    ? FormatAmount.sats(ConvertAmount.btcToSats(amount))
    : FormatAmount.fiat(amount, currency);
