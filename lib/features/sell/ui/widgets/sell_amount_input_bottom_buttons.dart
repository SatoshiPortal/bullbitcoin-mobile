import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SellAmountInputBottomButtons extends StatefulWidget {
  const SellAmountInputBottomButtons({
    super.key,
    required this.amountController,
    required this.isFiatCurrencyInput,
    required this.formKey,
    this.fiatCurrency,
  });

  final TextEditingController amountController;
  final bool isFiatCurrencyInput;
  final GlobalKey<FormState> formKey;
  final FiatCurrency? fiatCurrency;

  @override
  State<SellAmountInputBottomButtons> createState() =>
      _SellAmountInputBottomButtonsState();
}

class _SellAmountInputBottomButtonsState
    extends State<SellAmountInputBottomButtons> {
  @override
  void initState() {
    super.initState();
    widget.amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    setState(() {});
  }

  @override
  void didUpdateWidget(SellAmountInputBottomButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amountController != widget.amountController) {
      oldWidget.amountController.removeListener(_onAmountChanged);
      widget.amountController.addListener(_onAmountChanged);
    }
  }

  @override
  void dispose() {
    widget.amountController.removeListener(_onAmountChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (SellBloc bloc) => bloc.state is SellInitialState,
    );
    final sellState = context.watch<SellBloc>().state;

    // Only apply the fiat amount limit when the user is typing in fiat mode.
    final cadAmount = widget.isFiatCurrencyInput
        ? double.tryParse(widget.amountController.text) ?? 0.0
        : 0.0;

    if (isLoading) {
      return const LoadingLineContent(height: 48);
    } else if (sellState.needsKycUpgrade(cadAmount, currency: widget.fiatCurrency)) {
      return Column(
        children: [
          InfoCard(
            title: context.loc.sellKycPendingTitle,
            description: context.loc.sellKycPendingDescription,
            bgColor: context.appColors.tertiary.withValues(alpha: 0.1),
            tagColor: context.appColors.onTertiary,
          ),
          const Gap(16.0),
          BBButton.big(
            label: context.loc.sellCompleteKYC,
            onPressed: () {
              context.pushReplacementNamed(ExchangeRoute.exchangeKyc.name);
            },
            bgColor: context.appColors.primary,
            textColor: context.appColors.onPrimary,
          ),
        ],
      );
    } else {
      return BBButton.big(
        label: context.loc.sellSendPaymentContinue,
        onPressed: () {
          if (widget.formKey.currentState!.validate()) {
            final sellBloc = context.read<SellBloc>();
            final state = sellBloc.state;
            sellBloc.add(
              SellEvent.amountInputContinuePressed(
                amountInput: widget.amountController.text,
                isFiatCurrencyInput: widget.isFiatCurrencyInput,
                fiatCurrency:
                    widget.fiatCurrency ??
                    ((state is SellAmountInputState)
                        ? FiatCurrency.fromCode(
                          state.userSummary.currency ?? 'CAD',
                        )
                        : state is SellWalletSelectionState
                        ? state.fiatCurrency
                        : FiatCurrency.cad),
              ),
            );
          }
        },
        bgColor: context.appColors.secondary,
        textColor: context.appColors.onSecondary,
      );
    }
  }
}
