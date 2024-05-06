import 'package:bb_mobile/_model/currency.dart';
import 'package:bb_mobile/_ui/components/controls.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class AmountCurrencyDropDown extends StatelessWidget {
  const AmountCurrencyDropDown({super.key});

  @override
  Widget build(BuildContext context) {
    final currency =
        context.select((CurrencyCubit cubit) => cubit.state.currency);
    final currencyList = context
        .select((CurrencyCubit cubit) => cubit.state.updatedCurrencyList());

    return DropdownButton<String>(
      value: currency?.name,
      elevation: 16,
      style: const TextStyle(color: Colors.deepPurple),
      underline: const ColoredBox(color: Colors.transparent),
      onChanged: (String? value) {
        if (value == null) return;
        context.read<CurrencyCubit>().updateAmountCurrency(value.toLowerCase());
      },
      items: currencyList.map<DropdownMenuItem<String>>((Currency value) {
        return DropdownMenuItem<String>(
          value: value.name,
          child: BBText.body(value.shortName),
        );
      }).toList(),
    );
  }
}

class SettingsCurrencyDropDown extends StatelessWidget {
  const SettingsCurrencyDropDown({super.key});

  @override
  Widget build(BuildContext context) {
    final currency =
        context.select((CurrencyCubit x) => x.state.defaultFiatCurrency);
    final currencies =
        context.select((CurrencyCubit x) => x.state.currencyList ?? []);
    if (currency == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.body(
          'Currency',
        ),
        const Gap(16),
        BBDropDown<Currency>(
          isCentered: false,
          items: {
            for (final c in currencies)
              c: (label: c.getFullName(), enabled: true),
          },
          onChanged: (value) {
            context.read<CurrencyCubit>().changeDefaultCurrency(value);
          },
          value: currency,
        ),
        // SizedBox(
        //   height: 60,
        //   child: InputDecorator(
        //     decoration: InputDecoration(
        //       contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        //       border: OutlineInputBorder(
        //         borderRadius: BorderRadius.circular(40.0),
        //       ),
        //     ),
        //     child: DropdownButtonHideUnderline(
        //       child: DropdownButton<Currency>(
        //         items: currencies
        //             .map(
        //               (c) => DropdownMenuItem<Currency>(
        //                 value: c,
        //                 child: BBText.body(c.getFullName()),
        //               ),
        //             )
        //             .toList(),
        //         value: currency,
        //         onChanged: (c) {
        //           if (c != null) context.read<CurrencyCubit>().changeDefaultCurrency(c);
        //         },
        //       ),
        //     ),
        //   ),
        // ),
      ],
    );
  }
}
