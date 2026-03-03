import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
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

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;
    final currency = context.select((PayBloc bloc) => bloc.state.currency);
    final needsKycUpgrade = context.select(
      (PayBloc bloc) => bloc.state.needsKycUpgrade(enteredAmount),
    );

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
                fiatCurrency: currency,
              ),
              const Spacer(),
              if (needsKycUpgrade) ...[
                InfoCard(
                  title: context.loc.buyInputKycPending,
                  description: context.loc.buyInputKycMessage,
                  bgColor: context.appColors.tertiary.withValues(alpha: 0.1),
                  tagColor: context.appColors.onTertiary,
                ),
                const Gap(16.0),
                BBButton.big(
                  label: context.loc.buyInputCompleteKyc,
                  onPressed: () {
                    context.pushReplacementNamed(
                      ExchangeRoute.exchangeKyc.name,
                    );
                  },
                  bgColor: context.appColors.primary,
                  textColor: context.appColors.onPrimary,
                ),
              ] else
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
}
