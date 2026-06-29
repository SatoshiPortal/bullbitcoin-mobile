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
        SellInsufficientBalanceFailure() =>
          context.loc.sellInsufficientBalanceError,
        SellPrepareTransactionFailure() =>
          context.loc.sellErrorFeesNotCalculated,
        SellLoadUtxosFailure() => context.loc.sellErrorLoadUtxos,
        SellUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
      };
}
