import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CurrencyText extends StatelessWidget {
  const CurrencyText(
    this.satsAmount, {
    required this.showFiat,
    this.maxLines = 1,
    this.style,
    this.color,
    this.textAlign,
  });

  final int satsAmount;
  final bool showFiat;

  final int maxLines;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    String text = '';

    if (showFiat) {
      final price = context.select(
        (BitcoinPriceBloc _) => _.state.calculateFiatPrice(satsAmount),
      );
      if (price == null) return const SizedBox.shrink();

      text = price;
    } else {
      final unit = context.select((SettingsCubit _) => _.state?.bitcoinUnit);
      if (unit == null) return const SizedBox.shrink();

      final amount = context.select(
        (BitcoinPriceBloc _) => _.state.displayBTCAmount(satsAmount, unit),
      );

      if (amount == null) return const SizedBox.shrink();

      text = amount;
    }

    return BBText(
      text,
      style: style,
      color: color,
      textAlign: textAlign,
    );
  }
}
