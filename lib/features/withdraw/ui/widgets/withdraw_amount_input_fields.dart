import 'package:bb_mobile/core_deprecated/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_amount_currency_dropdown.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_amount_input_field.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class WithdrawAmountInputFields extends StatelessWidget {
  const WithdrawAmountInputFields({
    super.key,
    required this.amountController,
    required this.fiatCurrency,
    required this.onFiatCurrencyChanged,
  });

  final TextEditingController amountController;
  final FiatCurrency fiatCurrency;
  final void Function(FiatCurrency fiatCurrency) onFiatCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (WithdrawBloc bloc) => bloc.state is WithdrawInitialState,
    );
    final balances = context.select((WithdrawBloc bloc) {
      final state = bloc.state;
      if (state is WithdrawAmountInputState) {
        return state.userSummary.balances;
      }
      if (state is WithdrawRecipientInputState) {
        return state.userSummary.balances;
      }
      return null;
    });

    return Column(
      children: [
        ExchangeAmountInputField(
          isLoading: isLoading,
          amountController: amountController,
          fiatCurrency: fiatCurrency,
          fiatBalance:
              balances
                  ?.where((b) => b.currencyCode == fiatCurrency.code)
                  .firstOrNull,
        ),
        const Gap(16.0),
        ExchangeAmountCurrencyDropdown(
          isLoading: isLoading,
          initialCurrency: fiatCurrency,
          selectedCurrency: fiatCurrency.code,
          onCurrencyChanged: (String currencyCode) {
            final newFiatCurrency = FiatCurrency.fromCode(currencyCode);
            onFiatCurrencyChanged(newFiatCurrency);
          },
          balances: balances,
        ),
      ],
    );
  }
}
