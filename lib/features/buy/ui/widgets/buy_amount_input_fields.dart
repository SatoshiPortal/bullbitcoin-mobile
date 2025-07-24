import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
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
    final balances = context.select((BuyBloc bloc) => bloc.state.balances);

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
                              currency.decimals > 0
                                  ? [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(
                                        r'^\d+\.?\d{0,'
                                        '${currency.decimals}'
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
                              decimalDigits: currency.decimals,
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
                        currency.code,
                        style: context.font.displaySmall?.copyWith(
                          color: context.colour.primary,
                        ),
                      ),
                    ],
                  ),
                const Gap(8),
                if (currency == null)
                  const LoadingLineContent(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                  )
                else
                  Row(
                    children: [
                      Icon(Icons.swap_vert, color: context.colour.outline),
                      const Gap(8.0),
                      Text(
                        '0 BTC approx.',
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
                            _amountController.text =
                                balances[currency.code]?.toString() ?? '0';
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
