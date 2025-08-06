import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SellAmountCurrencyDropdown extends StatelessWidget {
  const SellAmountCurrencyDropdown({
    super.key,
    String? selectedCurrency,
    required ValueChanged<String> onCurrencyChanged,
  }) : _selectedCurrency = selectedCurrency,
       _onCurrencyChanged = onCurrencyChanged;

  final String? _selectedCurrency;
  final ValueChanged<String> _onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (SellBloc bloc) => bloc.state is SellInitialState,
    );
    final fiatCurrency = context.select((SellBloc bloc) {
      return bloc.state.fiatCurrency;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select currency', style: context.font.bodyMedium),
        const Gap(4.0),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 4,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(4.0),
            child: Center(
              child:
                  isLoading
                      ? const LoadingLineContent()
                      : DropdownButtonFormField<String>(
                        value: _selectedCurrency ?? fiatCurrency.code,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                          ),
                        ),
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: context.colour.secondary,
                        ),
                        items:
                            FiatCurrency.values
                                .map(
                                  (currency) => DropdownMenuItem<String>(
                                    value: currency.code,
                                    child: Text(
                                      '${currency.symbol} ${currency.code}',
                                      style: context.font.headlineSmall,
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _onCurrencyChanged(value);
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a currency';
                          }
                          return null;
                        },
                      ),
            ),
          ),
        ),
      ],
    );
  }
}
