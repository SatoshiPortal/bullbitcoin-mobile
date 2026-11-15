import 'package:bull_ui/bull_ui.dart' show BullAmount;
import 'package:primitives/primitives.dart' show Sats;
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:material_ui/material_ui.dart';
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
    this.overrideHideAmounts = false,
    this.interactive = false,
  });

  final int satsAmount;
  final bool showFiat;
  final int maxLines;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;
  final double? fiatAmount;
  final String? fiatCurrency;
  // If true, the amount will not be hidden even if the settings are set to hide amounts
  final bool overrideHideAmounts;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    if (fiatAmount == null && !showFiat) {
      final value = BigInt.from(satsAmount);
      return BullAmount(
        magnitude: Sats(value.abs()),
        isNegative: value.isNegative,
        style: style,
        color: color,
        textAlign: textAlign,
        overrideHideAmounts: overrideHideAmounts,
        interactive: interactive,
      );
    }
    String text = '';

    if (fiatAmount case final fiat?) {
      text = '${fiat.toStringAsFixed(2)} $fiatCurrency';
    } else if (showFiat) {
      final price = context.select(
        (BitcoinPriceBloc bloc) => bloc.state.calculateFiatPrice(satsAmount),
      );
      if (price == null) return const SizedBox.shrink();

      text = price;
    }

    final hideAmt = context.select(
      (SettingsCubit cubit) => cubit.state.hideAmounts ?? true,
    );

    if (hideAmt && !overrideHideAmounts) {
      text = '** ${text.split(' ').last}';
    }

    return Text(
      text,
      style: style?.copyWith(color: color),
      textAlign: textAlign,
    );
  }
}
