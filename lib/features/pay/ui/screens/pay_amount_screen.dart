import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/inputs/bb_keyboard_actions.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/widgets/pay_amount_input_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class PayAmountScreen extends StatefulWidget {
  const PayAmountScreen({super.key});

  @override
  State<PayAmountScreen> createState() => _PayAmountScreenState();
}

class _PayAmountScreenState extends State<PayAmountScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountNode = FocusNode();
  late final TextEditingController _descriptionController =
      TextEditingController();
  bool _needsKycUpgrade = false;

  @override
  void initState() {
    super.initState();

    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;
    final newValue = context.read<PayBloc>().state.needsKycUpgrade(
      enteredAmount,
    );
    if (newValue != _needsKycUpgrade) {
      setState(() {
        _needsKycUpgrade = newValue;
      });
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _amountNode.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;
    final currency = context.select((PayBloc bloc) => bloc.state.currency);
    // final needsKycUpgrade = context.select(
    //   (PayBloc bloc) => bloc.state.needsKycUpgrade(enteredAmount),
    // );

    return BullPage(
      topBar: BullTopBar(title: context.loc.payTitle, onBack: context.pop),
      safeArea: false,
      child: SafeArea(
        child: BBKeyboardActions(
          disableScroll: true,
          focusNodes: [_amountNode],
          child: Form(
            key: _formKey,
            child: BullScrollableColumn(
              crossAxisAlignment: .start,
              children: [
                const Gap(24.0),
                PayAmountInputFields(
                  amountController: _amountController,
                  focusNode: _amountNode,
                  fiatCurrency: currency,
                ),
                const Gap(24.0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        context.loc.payDescriptionLabel,
                        style: context.font.bodyMedium?.copyWith(
                          color: context.appColors.onSurfaceVariant,
                        ),
                      ),
                      const Gap(8.0),
                      BullInputText(
                        controller: _descriptionController,
                        value: _descriptionController.text,
                        hint: context.loc.payDescriptionHint,
                        maxLength: 140,
                        onChanged: (_) {},
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_needsKycUpgrade) ...[
                  BullInfoCard(
                    title: context.loc.buyInputKycPending,
                    description: context.loc.buyInputKycMessage,
                    bgColor: context.appColors.tertiary.withValues(alpha: 0.1),
                    tagColor: context.appColors.onTertiary,
                  ),
                  const Gap(16.0),
                  BullButton.primary(
                    label: context.loc.buyInputCompleteKyc,
                    onPressed: () {
                      context.pushReplacementNamed(
                        ExchangeRoute.exchangeKyc.name,
                      );
                    },
                  ),
                ] else
                  BullButton.primary(
                    label: context.loc.payContinue,
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final bloc = context.read<PayBloc>();
                        bloc.add(
                          PayEvent.amountInputContinuePressed(
                            amountInput: _amountController.text,
                            fiatCurrency: bloc.state.currency,
                            paymentDescription: _descriptionController.text
                                .trim(),
                          ),
                        );
                      }
                    },
                  ),
                const Gap(16.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
