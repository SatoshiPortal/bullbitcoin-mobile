import 'package:bb_mobile/core_deprecated/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/buttons/button.dart';
import 'package:bb_mobile/core_deprecated/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/widgets/pay_amount_input_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class PayAmountScreen extends StatefulWidget {
  const PayAmountScreen({super.key});

  @override
  State<PayAmountScreen> createState() => _PayAmountScreenState();
}

class _PayAmountScreenState extends State<PayAmountScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ScrollableColumn(
            crossAxisAlignment: .start,
            children: [
              const Gap(24.0),
              PayAmountInputFields(
                amountController: _amountController,
                fiatCurrency: context.select<PayBloc, FiatCurrency>(
                  (bloc) => bloc.state.currency,
                ),
              ),
              const Spacer(),
              BBButton.big(
                label: context.loc.payContinue,
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final bloc = context.read<PayBloc>();
                    bloc.add(
                      PayEvent.amountInputContinuePressed(
                        amountInput: _amountController.text,
                        fiatCurrency: bloc.state.currency,
                      ),
                    );
                  }
                },
                bgColor: context.appColors.secondary,
                textColor: context.appColors.onSecondary,
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
