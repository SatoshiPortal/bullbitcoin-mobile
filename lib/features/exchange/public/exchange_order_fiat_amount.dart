import 'package:bb_mobile/features/bitcoin_price/public/fiat_amount_text.dart';
import 'package:bull_ui/bull_ui.dart';

/// Displays the fiat value recorded on an exchange order.
class ExchangeOrderFiatAmount extends StatelessWidget {
  final double amount;
  final String currency;
  final TextStyle? style;

  const ExchangeOrderFiatAmount({
    super.key,
    required this.amount,
    required this.currency,
    this.style,
  });

  @override
  Widget build(BuildContext context) => FiatAmountText(
    formattedAmount: '${amount.toStringAsFixed(2)} $currency',
    hideAmounts: BullAmountScope.maybeOf(context)?.snapshot.hideAmounts ?? true,
    style: style,
  );
}
