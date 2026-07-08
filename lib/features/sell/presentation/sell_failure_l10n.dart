import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:flutter/widgets.dart';

extension SellFailureL10n on SellFailure {
  String toTranslated(BuildContext context) => switch (this) {
        SellUnauthenticatedFailure() => context.loc.sellUnauthenticatedError,
        SellBelowMinAmountFailure(:final minAmountSat) =>
          context.loc.sellBelowMinAmountError(FormatAmount.sats(minAmountSat)),
        SellAboveMaxAmountFailure(:final maxAmountSat) =>
          context.loc.sellAboveMaxAmountError(FormatAmount.sats(maxAmountSat)),
        SellInsufficientBalanceFailure(:final requiredAmountSat) =>
          context.loc.sellInsufficientBalanceError(
            FormatAmount.sats(requiredAmountSat),
          ),
        SellPrepareTransactionFailure() =>
          context.loc.sellErrorFeesNotCalculated,
        SellLoadUtxosFailure() => context.loc.sellErrorLoadUtxos,
        SellUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
      };
}
