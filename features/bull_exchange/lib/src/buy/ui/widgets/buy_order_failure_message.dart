import 'package:primitives/primitives.dart' show ConvertAmount, FormatAmount;
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/buy/domain/buy_failure.dart';
import 'package:bull_exchange/src/buy/presentation/buy_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart' show BullAmount, Gap, BullTypographyX;
import 'package:material_ui/material_ui.dart';

/// Renders whichever error the order creation failed with. Amount limits get
/// the amount appended, everything else falls back to its translation so that
/// the Continue button is never silently dead.
class BuyOrderFailureMessage extends StatelessWidget {
  const BuyOrderFailureMessage({required this.error});

  final BuyFailure error;

  @override
  Widget build(BuildContext context) {
    final errorStyle = context.bullType.body.copyWith(
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
          BullAmount.signedSats(
            ConvertAmount.btcToSats(amount),
            style: errorStyle,
            overrideHideAmounts: true,
            interactive: false,
          )
        else
          Text(FormatAmount.fiat(amount, currency), style: errorStyle),
      ],
    );
  }
}
