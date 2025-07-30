import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/sell/ui/widgets/sell_amount_currency_dropdown.dart';
import 'package:bb_mobile/features/sell/ui/widgets/sell_amount_input_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController = TextEditingController();
  bool _isFiatCurrencyInput = true;
  FiatCurrency? _fiatCurrency;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Adding the leading icon button here manually since we are in the first
        // route of a shellroute and so no back button is provided by default.
        leading:
            context.canPop()
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    context.pop();
                  },
                )
                : null,
        title: const Text('Sell Bitcoin'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ScrollableColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(24.0),
              SellAmountInputField(
                amountController: _amountController,
                fiatCurrency: _fiatCurrency,
                isFiatCurrencyInput: _isFiatCurrencyInput,
                onIsFiatCurrencyInputChanged: (bool isFiat) {
                  setState(() {
                    _isFiatCurrencyInput = isFiat;
                  });
                },
              ),
              const Gap(16.0),
              SellAmountCurrencyDropdown(
                selectedCurrency: _fiatCurrency?.code,
                onCurrencyChanged: (String currencyCode) {
                  setState(() {
                    _fiatCurrency = FiatCurrency.fromCode(currencyCode);
                  });
                },
              ),
              const Spacer(),
              BBButton.big(
                label: 'Continue',
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final sellBloc = context.read<SellBloc>();
                    final sellState = sellBloc.state;
                    sellBloc.add(
                      SellEvent.amountInputContinuePressed(
                        amountInput: _amountController.text,
                        isFiatCurrencyInput: _isFiatCurrencyInput,
                        fiatCurrency:
                            _fiatCurrency ??
                            ((sellState is SellAmountInputState)
                                ? FiatCurrency.fromCode(
                                  sellState.userSummary.currency ?? 'CAD',
                                )
                                : sellState is SellWalletSelectionState
                                ? sellState.fiatCurrency
                                : FiatCurrency.cad),
                      ),
                    );
                  }
                },
                bgColor: context.colour.secondary,
                textColor: context.colour.onSecondary,
              ),
              const Gap(16.0),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
