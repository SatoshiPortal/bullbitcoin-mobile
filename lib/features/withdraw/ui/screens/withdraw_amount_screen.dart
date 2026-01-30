import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:bb_mobile/features/withdraw/ui/widgets/withdraw_amount_input_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class WithdrawAmountScreen extends StatefulWidget {
  const WithdrawAmountScreen({super.key});

  @override
  State<WithdrawAmountScreen> createState() => _WithdrawAmountScreenState();
}

class _WithdrawAmountScreenState extends State<WithdrawAmountScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController = TextEditingController();
  FiatCurrency? _fiatCurrency;
  late final StreamSubscription<WithdrawState> stateSubscription;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<WithdrawBloc>();
    stateSubscription = bloc.stream.listen((state) {
      if (state is WithdrawAmountInputState && _fiatCurrency == null) {
        setState(() {
          _fiatCurrency = state.currency;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Adding the leading icon button here manually since we are in the first
        // route of a shellroute and so no back button is provided by default.
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  context.pop();
                },
              )
            : null,
        title: Text(context.loc.withdrawAmountTitle),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ScrollableColumn(
            crossAxisAlignment: .start,
            children: [
              const Gap(40.0),
              WithdrawAmountInputFields(
                amountController: _amountController,
                fiatCurrency: _fiatCurrency,
                onFiatCurrencyChanged: (FiatCurrency fiatCurrency) {
                  setState(() {
                    _fiatCurrency = fiatCurrency;
                  });
                },
              ),
              const Spacer(),
              BBButton.big(
                label: context.loc.withdrawAmountContinue,
                disabled: _fiatCurrency == null,
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    context.read<WithdrawBloc>().add(
                      WithdrawEvent.amountInputContinuePressed(
                        amountInput: _amountController.text,
                        fiatCurrency: _fiatCurrency!,
                      ),
                    );
                  }
                },
                bgColor: context.appColors.onSurface,
                textColor: context.appColors.surface,
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
    stateSubscription.cancel();
    super.dispose();
  }
}
