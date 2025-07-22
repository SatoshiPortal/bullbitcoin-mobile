import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
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
    this.fiatAmount,
    this.fiatCurrency,
  });

  final int satsAmount;
  final bool showFiat;
  final int maxLines;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;
  final double? fiatAmount;
  final String? fiatCurrency;

  @override
  Widget build(BuildContext context) {
    String text = '';

    if (fiatAmount != null) {
      text = '${fiatAmount!.toStringAsFixed(2)} $fiatCurrency';
    } else if (showFiat) {
      final price = context.select(
        (BitcoinPriceBloc bloc) => bloc.state.calculateFiatPrice(satsAmount),
      );
      if (price == null) return const SizedBox.shrink();

      text = price;
    } else {
      final unit = context.select(
        (SettingsCubit cubit) => cubit.state.bitcoinUnit,
      );
      if (unit == null) return const SizedBox.shrink();

      if (unit == BitcoinUnit.btc) {
        text = FormatAmount.btc(ConvertAmount.satsToBtc(satsAmount));
      } else {
        text = FormatAmount.sats(satsAmount);
      }
    }

    final hideAmt = context.select(
      (SettingsCubit cubit) => cubit.state.hideAmounts ?? true,
    );

    if (hideAmt) {
      text = '** ${text.split(' ').last}';
    }

    return Text(
      text,
      style: style?.copyWith(color: color),
      textAlign: textAlign,
    );
  }
}
