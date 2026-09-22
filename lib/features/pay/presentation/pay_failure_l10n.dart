import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:flutter/widgets.dart';

extension PayFailureL10n on PayFailure {
  String toTranslated(BuildContext context) => switch (this) {
    PayUnauthenticatedFailure() => context.loc.payUnauthenticatedError,
    PayBelowMinAmountFailure(:final minAmount, :final currency) =>
      context.loc.payBelowMinAmountError(
        FormatAmount.fiat(minAmount, currency),
      ),
    PayAboveMaxAmountFailure(:final maxAmount, :final currency) =>
      context.loc.payAboveMaxAmountError(
        FormatAmount.fiat(maxAmount, currency),
      ),
    PayDepositAddressChangedFailure() =>
      context.loc.payDepositAddressChangedError,
    PayInsufficientBalanceFailure() => context.loc.payInsufficientBalanceError,
    PayFeeBelowRelayFloorFailure() => context.loc.payErrorFeeBelowRelayFloor,
    PayFeesUnavailableFailure() => context.loc.payErrorFeesUnavailable,
    PayConfidentialSepaNotActivatedFailure() =>
      context.loc.recipientsConfidentialSepaNotActivatedError,
    // Never `logMessage`. This arm used to be `unexpected: (m) => m`, which put
    // BDK/LWK/Dio text straight onto the payment screen.
    PayUnexpectedFailure() => context.loc.payUnexpectedError,
  };
}
