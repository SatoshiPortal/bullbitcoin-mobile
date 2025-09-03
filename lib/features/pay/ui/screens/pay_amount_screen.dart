import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/widgets/pay_amount_input_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class PayAmountScreen extends StatefulWidget {
  const PayAmountScreen({super.key});

  @override
  State<PayAmountScreen> createState() => _PayAmountScreenState();
}

class _PayAmountScreenState extends State<PayAmountScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController = TextEditingController();
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
        title: const Text('Pay'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ScrollableColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(24.0),
              PayAmountInputFields(
                amountController: _amountController,
                fiatCurrency: _fiatCurrency ?? FiatCurrency.cad,
                onFiatCurrencyChanged: (FiatCurrency fiatCurrency) {
                  setState(() {
                    _fiatCurrency = fiatCurrency;
                  });
                },
              ),
              const Spacer(),
              BBButton.big(
                label: 'Continue',
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final payBloc = context.read<PayBloc>();
                    final payState = payBloc.state;
                    payBloc.add(
                      PayEvent.amountInputContinuePressed(
                        amountInput: _amountController.text,
                        isFiatCurrencyInput: true, // Always fiat for Pay
                        fiatCurrency:
                            _fiatCurrency ??
                            ((payState is PayAmountInputState)
                                ? FiatCurrency.fromCode(
                                  payState.userSummary.currency ?? 'CAD',
                                )
                                : payState is PayRecipientInputState
                                ? payState.currency
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
