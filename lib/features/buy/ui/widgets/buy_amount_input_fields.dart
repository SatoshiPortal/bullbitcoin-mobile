import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

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
    final currencyCode = context.select(
      (BuyBloc bloc) => bloc.state.currencyInput,
    );
    final balance = context.select((BuyBloc bloc) => bloc.state.balance);
    final balances = context.select((BuyBloc bloc) => bloc.state.balances);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText('Amount you spend', style: context.font.bodyMedium),
        const Gap(4.0),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 2,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(2.0),
            child: Center(
              child:
                  currencyCode.isEmpty
                      ? const LoadingLineContent()
                      : TextFormField(
                        controller: _amountController,
                        enabled: currencyCode.isNotEmpty,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: context.font.headlineMedium,
                        decoration: InputDecoration(
                          hintText: '0 $currencyCode',
                          hintStyle: context.font.headlineMedium?.copyWith(
                            color: context.colour.outline,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                          ),
                        ),
                      ),
            ),
          ),
        ),
        const Gap(2.0),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BBText(
              'Balance: $balance',
              style: context.font.labelSmall,
              color:
                  balance == null ? Colors.transparent : context.colour.outline,
            ),
          ],
        ),
        const Gap(16.0),
        BBText('Select currency', style: context.font.bodyMedium),
        const Gap(4.0),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 4,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(4.0),
            child: Center(
              child: DropdownButtonFormField<String>(
                value: currencyCode.isEmpty ? null : currencyCode,
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
                            child: BBText(
                              currencyCode,
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
