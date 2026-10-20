import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/currency_text.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/features/buy/presentation/buy_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

/// Renders whichever error the order creation failed with. Amount limits get
/// the amount appended, everything else falls back to its translation so that
/// the Continue button is never silently dead.
class BuyOrderFailureMessage extends StatelessWidget {
  const BuyOrderFailureMessage({required this.error});

  final BuyFailure error;

  @override
  Widget build(BuildContext context) {
    final errorStyle = context.font.bodyMedium?.copyWith(
      color: context.appColors.error,
    );

    final (String label, double amount, String currency)? limit =
        switch (error) {
          BuyBelowMinAmountFailure(:final minAmount, :final currency) => (
            context.loc.buyInputMinAmountError,
            minAmount,
            currency,
          ),
          BuyAboveMaxAmountFailure(:final maxAmount, :final currency) => (
            context.loc.buyInputMaxAmountError,
            maxAmount,
            currency,
          ),
          _ => null,
        };

    if (limit == null) {
      return Center(
        child: Text(
          error.toTranslated(context),
          style: errorStyle,
          textAlign: .center,
        ),
      );
    }

    final (label, amount, currency) = limit;
    // The api denominates a limit either in fiat or in bitcoin; only the latter
    // can be shown in the user's bitcoin unit.
    final isBitcoinLimit = currency == 'BTC' || currency == 'LBTC';
    return Row(
      mainAxisAlignment: .center,
      children: [
        Text(label, style: errorStyle),
        const Gap(4),
        if (isBitcoinLimit)
          CurrencyText(
            ConvertAmount.btcToSats(amount),
            showFiat: false,
            style: errorStyle,
            overrideHideAmounts: true,
          )
        else
          Text(FormatAmount.fiat(amount, currency), style: errorStyle),
      ],
    );
  }
}
