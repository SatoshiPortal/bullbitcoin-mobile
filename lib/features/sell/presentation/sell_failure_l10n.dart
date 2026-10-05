import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:flutter/widgets.dart';

extension SellFailureL10n on SellFailure {
  String toTranslated(BuildContext context) => switch (this) {
    SellUnauthenticatedFailure() => context.loc.sellUnauthenticatedError,
    SellBelowMinAmountFailure() => context.loc.sellBelowMinAmountError,
    SellAboveMaxAmountFailure() => context.loc.sellAboveMaxAmountError,
    SellOrderNotFoundFailure() => context.loc.sellOrderNotFoundError,
    SellOrderAlreadyConfirmedFailure() =>
      context.loc.sellOrderAlreadyConfirmedError,
    SellDepositAddressChangedFailure() =>
      context.loc.sellDepositAddressChangedError,
    SellInsufficientBalanceFailure() =>
      context.loc.sellInsufficientBalanceError,
    SellFeeBelowRelayFloorFailure() => context.loc.sellErrorFeeBelowRelayFloor,
    SellFeesUnavailableFailure() => context.loc.sellErrorFeesUnavailable,
    // Never `logMessage`. That arm used to return the raw exception text —
    // "PrepareBitcoinSendException: ..." — straight to the payment screen.
    SellUnexpectedFailure() => context.loc.sellUnexpectedError,
  };
}
