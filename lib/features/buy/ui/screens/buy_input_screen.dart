import 'package:bb_mobile/core/exchange/domain/errors/buy_error.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/widgets/buy_amount_input_fields.dart';
import 'package:bb_mobile/features/buy/ui/widgets/buy_destination_input_fields.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/fund_exchange/ui/fund_exchange_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BuyInputScreen extends StatelessWidget {
  const BuyInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isStarted = context.select((BuyBloc bloc) => bloc.state.isStarted);
    final canCreateOrder = context.select(
      (BuyBloc bloc) => bloc.state.canCreateOrder,
    );
    final isCreatingOrder = context.select(
      (BuyBloc bloc) => bloc.state.isCreatingOrder,
    );
    final belowMinAmountError = context.select((BuyBloc bloc) {
      final error = bloc.state.createOrderBuyError;
      return error is BelowMinAmountBuyError ? error : null;
    });
    final aboveMaxAmountError = context.select((BuyBloc bloc) {
      final error = bloc.state.createOrderBuyError;
      return error is AboveMaxAmountBuyError ? error : null;
    });
    final isFullyVerifiedKycLevel = context.select(
      (BuyBloc bloc) => bloc.state.isFullyVerifiedKycLevel,
    );
    final showInsufficientBalanceError = context.select(
      (BuyBloc bloc) => bloc.state.showInsufficientBalanceError,
    );

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
        title: Text(context.loc.buyInputTitle),
      ),
      body: SafeArea(
        child: ScrollableColumn(
          crossAxisAlignment: .start,
          children: [
            const Gap(24),
            const BuyAmountInputFields(),
            const Gap(16.0),
            const BuyDestinationInputFields(),
            const Spacer(),
            Column(
              mainAxisSize: .min,
              children: [
                if (isCreatingOrder)
                  const Center(child: CircularProgressIndicator()),
                if (belowMinAmountError != null || aboveMaxAmountError != null)
                  Row(
                    mainAxisAlignment: .center,
                    children: [
                      Text(
                        belowMinAmountError != null
                            ? context.loc.buyInputMinAmountError
                            : context.loc.buyInputMaxAmountError,
                        style: context.font.bodyMedium?.copyWith(
                          color: context.appColors.error,
                        ),
                      ),
                      const Gap(4),
                      CurrencyText(
                        belowMinAmountError != null
                            ? belowMinAmountError.minAmountSat
                            : aboveMaxAmountError!.maxAmountSat,
                        showFiat: false,
                        style: context.font.bodyMedium?.copyWith(
                          color: context.appColors.error,
                        ),
                        overrideHideAmounts: true,
                      ),
                    ],
                  ),

                const Gap(16),
                if (isStarted) ...[
                  if (!isFullyVerifiedKycLevel) ...[
                    InfoCard(
                      title: context.loc.buyInputKycPending,
                      description: context.loc.buyInputKycMessage,
                      bgColor: context.appColors.tertiary.withValues(
                        alpha: 0.1,
                      ),
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
                  ] else if (showInsufficientBalanceError) ...[
                    InfoCard(
                      title: context.loc.buyInputInsufficientBalance,
                      description:
                          context.loc.buyInputInsufficientBalanceMessage,
                      bgColor: context.appColors.tertiary.withValues(
                        alpha: 0.1,
                      ),
                      tagColor: context.appColors.onTertiary,
                    ),
                    const Gap(16.0),
                    BBButton.big(
                      label: context.loc.buyInputFundAccount,
                      onPressed: () {
                        context.pushReplacementNamed(
                          FundExchangeRoute.fundExchangeAccount.name,
                        );
                      },
                      bgColor: context.appColors.primary,
                      textColor: context.appColors.onPrimary,
                    ),
                  ] else
                    BBButton.big(
                      label: context.loc.buyInputContinue,
                      disabled: !canCreateOrder || isCreatingOrder,
                      onPressed: () {
                        context.read<BuyBloc>().add(
                          const BuyEvent.createOrder(),
                        );
                      },
                      bgColor: context.appColors.secondary,
                      textColor: context.appColors.onSecondary,
                    ),
                ] else ...[
                  const LoadingLineContent(height: 56, width: double.infinity),
                ],
                const Gap(16.0),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
