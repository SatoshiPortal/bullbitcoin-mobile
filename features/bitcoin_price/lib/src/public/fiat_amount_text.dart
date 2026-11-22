import 'package:bitcoin_price/src/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Displays a fiat amount with the caller's amount-privacy preference.
class FiatAmountText extends StatelessWidget {
  final String? formattedAmount;
  final int? _sats;
  final bool hideAmounts;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;

  const FiatAmountText({
    super.key,
    required this.formattedAmount,
    required this.hideAmounts,
    this.style,
    this.color,
    this.textAlign,
  }) : _sats = null;

  const FiatAmountText.quote(
    int sats, {
    super.key,
    required this.hideAmounts,
    this.style,
    this.color,
    this.textAlign,
  }) : _sats = sats,
       formattedAmount = null;

  @override
  Widget build(BuildContext context) {
    final sats = _sats;
    final amount = sats == null
        ? formattedAmount
        : context.select(
            (BitcoinPriceBloc bloc) => bloc.state.calculateFiatPrice(sats),
          );
    if (amount == null) return const SizedBox.shrink();
    return Text(
      hideAmounts ? '** ${amount.split(' ').last}' : amount,
      style: style?.copyWith(color: color),
      textAlign: textAlign,
    );
  }
}
