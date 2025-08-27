import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/features/dca/presentation/dca_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

class DcaAmountInputFields extends StatelessWidget {
  const DcaAmountInputFields({
    super.key,
    required TextEditingController amountController,
    FiatCurrency? currency,
  }) : _amountController = amountController,
       _currency = currency;

  final TextEditingController _amountController;
  final FiatCurrency? _currency;

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (DcaBloc bloc) => bloc.state is DcaInitialState,
    );

    final currency =
        _currency ??
        context.select((DcaBloc bloc) {
          return bloc.state.currency;
        });
    final amountInputDecimals = currency?.decimals ?? 2;

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
                if (isLoading)
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an amount';
                            }

                            if (double.tryParse(value) == null) {
                              return 'Invalid amount';
                            }
                            return null;
                          },
                        ),
                      ),
                      const Gap(8.0),
                      Text(
                        currency?.code ?? '',
                        style: context.font.displaySmall?.copyWith(
                          color: context.colour.primary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
