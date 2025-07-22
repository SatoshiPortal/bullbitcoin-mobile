import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeFiatBalance extends StatelessWidget {
  const HomeFiatBalance({super.key, required this.balanceSat});

  final int balanceSat;

  @override
  Widget build(BuildContext context) {
    final fiatPriceIsNull = context.select(
      (BitcoinPriceBloc bitcoinPriceBloc) =>
          bitcoinPriceBloc.state.bitcoinPrice == null,
    );

    if (fiatPriceIsNull) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.colour.surfaceDim),
        color: context.colour.surfaceDim,
      ),
      child: CurrencyText(
        balanceSat,
        showFiat: true,
        // '\$0.0 CAD',
        style: context.font.bodyLarge,
        color: context.colour.onPrimary,
      ),
    );
  }
}
