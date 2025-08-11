import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SellAmountInputBottomButtons extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (SellBloc bloc) => bloc.state is SellInitialState,
    );
    final isFullyVerifiedKycLevel = context.select(
      (SellBloc bloc) => bloc.state.isFullyVerifiedKycLevel,
    );
    final isLimitedKyc = context.select(
      (SellBloc bloc) => bloc.state.isLimitedKycLevel,
    );
    // For CAD, we allow selling with limited KYC.
    // For other fiat currencies, we require full KYC.
    final isKycLevelOk =
        isFullyVerifiedKycLevel ||
        fiatCurrency == FiatCurrency.cad && isLimitedKyc;

    if (isLoading) {
      return const LoadingLineContent(height: 48);
    } else if (!isKycLevelOk) {
      return Column(
        children: [
          InfoCard(
            title: 'KYC ID Verification Pending',
            description: 'You must complete ID Verification first',
            bgColor: context.colour.tertiary.withValues(alpha: 0.1),
            tagColor: context.colour.onTertiary,
          ),
          const Gap(16.0),
          BBButton.big(
            label: 'Complete KYC',
            onPressed: () {
              context.pushReplacementNamed(ExchangeRoute.exchangeKyc.name);
            },
            bgColor: context.colour.primary,
            textColor: context.colour.onPrimary,
          ),
        ],
      );
    } else {
      return BBButton.big(
        label: 'Continue',
        onPressed: () {
          if (formKey.currentState!.validate()) {
            final sellBloc = context.read<SellBloc>();
            final sellState = sellBloc.state;
            sellBloc.add(
              SellEvent.amountInputContinuePressed(
                amountInput: amountController.text,
                isFiatCurrencyInput: isFiatCurrencyInput,
                fiatCurrency:
                    fiatCurrency ??
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
      );
    }
  }
}
