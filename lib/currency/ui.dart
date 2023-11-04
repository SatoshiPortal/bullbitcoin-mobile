import 'package:bb_mobile/_model/currency.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class EnterAmount extends StatefulWidget {
  const EnterAmount({super.key});

  @override
  State<EnterAmount> createState() => _EnterAmountState();
}

class _EnterAmountState extends State<EnterAmount> {
  final FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final _ = context.select((CurrencyCubit cubit) => cubit.state.currency);

    final sendAll = context.select((SendCubit cubit) => cubit.state.sendAllCoin);
    // if (sendAll) return const SizedBox.shrink();
    final isSats = context.select((CurrencyCubit cubit) => cubit.state.unitsInSats);

    final fiatSelected = context.select((CurrencyCubit cubit) => cubit.state.fiatSelected);
    final tempAmt = context.select((SendCubit cubit) => cubit.state.tempAmount);

    // var amountStr = '';
    // if (!fiatSelected)
    //   amountStr = context.select(
    //     (SettingsCubit cubit) => cubit.state.getAmountInUnits(
    //       sendAll ? balance : amount,
    //       removeText: true,
    //       hideZero: true,
    //       removeEndZeros: true,
    //       isSats: isSats,
    //     ),
    //   );
    // else
    //   amountStr = fiatAmt.toStringAsFixed(2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title('    Amount'),
        const Gap(4),
        if (sendAll) ...[
          const Gap(4),
          const BBText.bodySmall('    Entire balance will be sent'),
          const Gap(4),
        ] else
          IgnorePointer(
            ignoring: sendAll,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: sendAll ? 0.5 : 1,
              child: Stack(
                children: [
                  Focus(
                    focusNode: _focusNode,
                    child: BBAmountInput(
                      disabled: sendAll,
                      value: tempAmt,
                      hint: 'Enter amount',
                      // onRightTap: () {
                      //   // context.read<SettingsCubit>().toggleUnitsInSats();
                      // },
                      isSats: isSats,
                      btcFormatting: !isSats && !fiatSelected,
                      onChanged: (txt) {
                        // final aLen = amountStr.length;
                        // final tLen = txt.length;

                        // print('\n\n');
                        // print('||--- $txt');

                        // if ((tLen - aLen) > 1 || (aLen - tLen) > 1) {
                        //   return;
                        // }

                        // var clean = txt.replaceAll(',', '');
                        // if (isSats)
                        //   clean = clean.replaceAll('.', '');
                        // else if (!txt.contains('.')) {
                        //   return;
                        // }
                        // final amt = context.read<SettingsCubit>().state.getSatsAmount(clean);
                        // print('----- $amt');

                        context.read<CurrencyCubit>().updateAmount(txt);
                      },
                    ),
                  ),
                  const CenterRight(
                    child: Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: SendCurrencyDropDown(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const Gap(4),
        if (!sendAll) const SendConversionAmt(),
      ],
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();

    super.dispose();
  }
}

class SendCurrencyDropDown extends StatelessWidget {
  const SendCurrencyDropDown({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = context.select((CurrencyCubit cubit) => cubit.state.currency);
    final currencyList = context.select((CurrencyCubit cubit) => cubit.state.updatedCurrencyList());

    return DropdownButton<String>(
      value: currency?.name,
      // icon: const Icon(Icons.arrow_downward),
      // iconSize: 24,
      elevation: 16,
      style: const TextStyle(color: Colors.deepPurple),
      underline: const ColoredBox(color: Colors.transparent),
      onChanged: (String? amt) {
        if (amt == null) return;
        context.read<CurrencyCubit>().updateAmountCurrency(amt.toLowerCase());
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

class SendConversionAmt extends StatelessWidget {
  const SendConversionAmt({super.key});

  @override
  Widget build(BuildContext context) {
    final fiatSelected = context.select((CurrencyCubit cubit) => cubit.state.fiatSelected);
    final isDefaultSats = context.select((CurrencyCubit cubit) => cubit.state.unitsInSats);

    final fiatAmt = context.select((CurrencyCubit cubit) => cubit.state.fiatAmt);
    final satsAmt = context.select((CurrencyCubit cubit) => cubit.state.amount);
    final defaultCurrency = context.select((CurrencyCubit cubit) => cubit.state.currency);

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

class InvoiceAmountField extends StatefulWidget {
  const InvoiceAmountField({super.key});

  @override
  State<InvoiceAmountField> createState() => _InvoiceAmountFieldState();
}

class _InvoiceAmountFieldState extends State<InvoiceAmountField> {
  final FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final _ = context.select((CurrencyCubit cubit) => cubit.state.currency);

    final isSats = context.select((CurrencyCubit cubit) => cubit.state.unitsInSats);

    final fiatSelected = context.select((CurrencyCubit cubit) => cubit.state.fiatSelected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: 1,
          child: Stack(
            children: [
              Focus(
                focusNode: _focusNode,
                child: BBAmountInput(
                  disabled: false,
                  hint: 'Enter amount',
                  isSats: isSats,
                  btcFormatting: !isSats && !fiatSelected,
                  onChanged: (txt) {
                    context.read<CurrencyCubit>().updateAmount(txt);
                  },
                ),
              ),
              const CenterRight(
                child: Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: ReceiveCurrencyDropDown(),
                ),
              ),
            ],
          ),
        ),
        const Gap(4),
        const ReceiveConversionAmt(),
      ],
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();

    super.dispose();
  }
}

class ReceiveCurrencyDropDown extends StatelessWidget {
  const ReceiveCurrencyDropDown({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = context.select((CurrencyCubit cubit) => cubit.state.currency);
    final currencyList = context.select((CurrencyCubit cubit) => cubit.state.updatedCurrencyList());

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

class ReceiveConversionAmt extends StatelessWidget {
  const ReceiveConversionAmt({super.key});

  @override
  Widget build(BuildContext context) {
    final fiatSelected = context.select((CurrencyCubit cubit) => cubit.state.fiatSelected);
    final isDefaultSats = context.select((CurrencyCubit cubit) => cubit.state.unitsInSats);

    final fiatAmt = context.select((CurrencyCubit cubit) => cubit.state.fiatAmt);
    final satsAmt = context.select((CurrencyCubit cubit) => cubit.state.amount);
    final defaultCurrency = context.select((CurrencyCubit cubit) => cubit.state.currency);

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

class Currencyx extends StatelessWidget {
  const Currencyx({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = context.select((CurrencyCubit x) => x.state.currency);
    final currencies = context.select((CurrencyCubit x) => x.state.currencyList ?? []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.body(
          'Currency',
        ),
        const Gap(4),
        SizedBox(
          height: 60,
          child: InputDecorator(
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(40.0),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Currency>(
                items: currencies
                    .map(
                      (c) => DropdownMenuItem<Currency>(
                        value: c,
                        child: BBText.body(c.getFullName()),
                      ),
                    )
                    .toList(),
                value: currency,
                onChanged: (c) {
                  if (c != null) context.read<CurrencyCubit>().changeDefaultCurrency(c);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
