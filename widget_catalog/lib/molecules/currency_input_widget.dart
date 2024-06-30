import 'package:bb_arch/_pkg/currency/models/currency.dart';
import 'package:bb_arch/_pkg/utils.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import 'package:bb_arch/_ui/molecules/currency_input_widget.dart';

const currencies = [
  btcCurrency,
  satsCurrency,
  Currency(code: 'USD', isFiat: true, name: 'US dollar', price: 61499.30),
  Currency(code: 'CAD', isFiat: true, name: 'Canadian Dollar', price: 84214.07),
  Currency(code: 'CRC', isFiat: true, name: 'Costa Rican colón', price: 32162424.21),
  Currency(code: 'EUR', isFiat: true, name: 'Euro', price: 57369.62),
  Currency(code: 'INR', isFiat: true, name: 'Indian Rupee', price: 5126849.17),
];

const List<Currency> emptyCurrencyList = [];

@widgetbook.UseCase(name: 'Default', type: CurrencyInput)
Widget buildCurrencyInputUseCase(BuildContext context) {

  return CurrencyInput(
    currencies: context.knobs.list(
      label: 'currencies',
      description: 'List of currencies to display in the component',
      options: [
        currencies,
        emptyCurrencyList,
      ],
      labelBuilder: (value) => value.isNotEmpty ? 'Full list': 'Empty list',
    ),

    unitsInSats: context.knobs.boolean(
      label: 'unitsInSats',
      initialValue: false,
      description: 'Making it true will display Sats below when any fiat currencies are chosen'
    ),

    // ? NOTE: No knobs or equivalent for action functions. We can just add print statements and see values in the debug console
    onChange: (int sats, Currency selectedCurrency) {
      print(sats);
      print(selectedCurrency);
    },

    // ? NOTE: This will not work now. If this needs to work, we need to populate 'initialCurrency' as well. But knob for initialCurrency is pending.
    // initialPrice: context.knobs.doubleOrNull.input(
    //   label: 'initialPrice',
    //   description: 'Initial price to populate in the field while rendering the component. Useful if you want to show this component with some pre-filled values. This is not a controllable field.',
    // ),

     // TODO: Not sure how to make knob for this. Maybe custom knob?,
    // initialCurrency: currencies[4],

    // TODO: Not sure how to make knob for this. Maybe custom knob?
    defaultFiat: Currency(
      code: context.knobs.list(
        label: 'defaultFiat.code',
        options: currencies.map((e) => e.name).toList(),
      ),
      isFiat: context.knobs.boolean(
        label: 'defaultFiat.isFiat',
      ),
      name: context.knobs.string(label: 'defaultFiat.name'),
      price: context.knobs.double.input(label: 'defaultFiat.price')
    ),
  );
}
