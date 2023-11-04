import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ConversionAmt extends StatelessWidget {
  const ConversionAmt({super.key});

  @override
  Widget build(BuildContext context) {
    final fiatSelected = context.select((CurrencyCubit cubit) => cubit.state.fiatSelected);
    final isDefaultSats = context.select((CurrencyCubit cubit) => cubit.state.unitsInSats);

    final fiatAmt = context.select((CurrencyCubit cubit) => cubit.state.fiatAmt);
    final satsAmt = context.select((CurrencyCubit cubit) => cubit.state.amount);
    final defaultCurrency =
        context.select((CurrencyCubit cubit) => cubit.state.defaultFiatCurrency);

    var amt = '';
    var unit = '';

    if (fiatSelected) {
      unit = isDefaultSats ? 'sats' : 'BTC';
      amt = context.select(
        (CurrencyCubit _) => _.state.getAmountInUnits(
          satsAmt,
          removeText: true,
        ),
      );
    } else {
      unit = defaultCurrency!.name;
      amt = fiatAmt.toStringAsFixed(2);
    }

    return Row(
      children: [
        const BBText.title('    ≈ '),
        const Gap(4),
        BBText.title(amt),
        const Gap(4),
        BBText.title(unit),
      ],
    );
  }
}
