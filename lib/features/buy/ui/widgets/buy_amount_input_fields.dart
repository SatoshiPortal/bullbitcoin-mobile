import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

class BuyAmountInputFields extends StatefulWidget {
  const BuyAmountInputFields({super.key});

  @override
  State<BuyAmountInputFields> createState() => _BuyAmountInputFieldsState();
}

class _BuyAmountInputFieldsState extends State<BuyAmountInputFields> {
  late TextEditingController _amountController;

  @override
  void initState() {
    // Initialize the controller with the amount input from state if available
    final amountInput = context.read<BuyBloc>().state.amountInput;
    _amountController = TextEditingController(text: amountInput);
    _amountController.addListener(() {
      context.read<BuyBloc>().add(
        BuyEvent.amountInputChanged(_amountController.text),
      );
    });

    super.initState();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.select((BuyBloc bloc) => bloc.state.currency);
    final balance = context.select((BuyBloc bloc) => bloc.state.balance);
    final balances = context.select((BuyBloc bloc) => bloc.state.balances);
    final fiatAmount = context.select((BuyBloc bloc) => bloc.state.amount);
    final amountSat = context.select((BuyBloc bloc) => bloc.state.amountSat);
    final bitcoinUnit = context.select(
      (BuyBloc bloc) => bloc.state.bitcoinUnit,
    );
    final isFiatCurrencyInput = context.select(
      (BuyBloc bloc) => bloc.state.isFiatCurrencyInput,
    );
    final amountInputDecimals =
        isFiatCurrencyInput ? currency?.decimals ?? 2 : bitcoinUnit.decimals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter amount', style: context.font.bodyMedium),
        const Gap(4.0),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currency == null)
                  const LoadingLineContent(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters:
                              amountInputDecimals > 0
                                  ? [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(
                                        r'^\d+\.?\d{0,'
                                        '$amountInputDecimals'
                                        '}',
                                      ),
                                    ),
                                  ]
                                  : [FilteringTextInputFormatter.digitsOnly],
                          style: context.font.displaySmall?.copyWith(
                            color: context.colour.primary,
                          ),
                          decoration: InputDecoration(
                            hintText: NumberFormat.decimalPatternDigits(
                              decimalDigits: amountInputDecimals,
                            ).format(0),
                            hintStyle: context.font.displaySmall?.copyWith(
                              color: context.colour.primary,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const Gap(8.0),
                      Text(
                        isFiatCurrencyInput ? currency.code : bitcoinUnit.code,
                        style: context.font.displaySmall?.copyWith(
                          color: context.colour.primary,
                        ),
                      ),
                    ],
                  ),
                const Gap(16),
                if (currency == null)
                  const LoadingLineContent(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                  )
                else
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          context.read<BuyBloc>().add(
                            const BuyEvent.fiatCurrencyInputToggled(),
                          );
                          // Clear the amount input when switching currency type
                          // manually to avoid confusion with the previous input
                          // and since the input formatters will change.
                          _amountController.clear();
                        },
                        child: Icon(
                          Icons.swap_vert,
                          color: context.colour.outline,
                        ),
                      ),
                      const Gap(8.0),
                      CurrencyText(
                        amountSat ?? 0,
                        showFiat: !isFiatCurrencyInput,
                        style: context.font.bodyMedium?.copyWith(
                          color: context.colour.outline,
                        ),
                        fiatCurrency: currency.code,
                        fiatAmount: !isFiatCurrencyInput ? fiatAmount : null,
                      ),
                      Text(
                        ' approx.',
                        style: context.font.bodyMedium?.copyWith(
                          color: context.colour.outline,
                        ),
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            if (!isFiatCurrencyInput) {
                              context.read<BuyBloc>().add(
                                const BuyEvent.fiatCurrencyInputToggled(),
                              );
                            }
                            _amountController.text = balance?.toString() ?? '0';
                          },
                          child: Text(
                            'Max',
                            style: context.font.bodyMedium?.copyWith(
                              color: context.colour.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const Gap(16.0),
        Text('Payment method', style: context.font.bodyMedium),
        const Gap(4.0),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 4,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(4.0),
            child: Center(
              child: DropdownButtonFormField<String>(
                value: currency?.code,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: context.colour.secondary,
                ),
                items:
                    balances.keys
                        .map(
                          (currencyCode) => DropdownMenuItem<String>(
                            value: currencyCode,
                            child: Text(
                              '$currencyCode Balance - ${FormatAmount.fiat(balances[currencyCode] ?? 0, currencyCode, simpleFormat: true)}',
                              style: context.font.headlineSmall,
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) {
                    context.read<BuyBloc>().add(
                      BuyEvent.currencyInputChanged(value),
                    );
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
