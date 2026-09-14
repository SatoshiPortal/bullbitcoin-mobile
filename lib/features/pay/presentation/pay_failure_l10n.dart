import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:flutter/widgets.dart';

extension PayFailureL10n on PayFailure {
  String toTranslated(BuildContext context) => switch (this) {
    PayUnauthenticatedFailure() => context.loc.payUnauthenticatedError,
    PayBelowMinAmountFailure() => context.loc.payBelowMinAmountError,
    PayAboveMaxAmountFailure() => context.loc.payAboveMaxAmountError,
    PayDepositAddressChangedFailure() =>
      context.loc.payDepositAddressChangedError,
    PayInsufficientBalanceFailure() => context.loc.payInsufficientBalanceError,
    PayFeeBelowRelayFloorFailure() => context.loc.payErrorFeeBelowRelayFloor,
    PayFeesUnavailableFailure() => context.loc.payErrorFeesUnavailable,
    // Never `logMessage`. This arm used to be `unexpected: (m) => m`, which put
    // BDK/LWK/Dio text straight onto the payment screen.
    PayUnexpectedFailure() => context.loc.payUnexpectedError,
  };
}
