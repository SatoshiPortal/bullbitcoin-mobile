import 'package:bb_mobile/core/exchange/domain/errors/buy_error.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/inputs/bb_keyboard_actions.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/core/widgets/switch/bb_switch.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/widgets/buy_amount_input_fields.dart';
import 'package:bb_mobile/features/buy/ui/widgets/buy_destination_input_fields.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/fund_exchange/fund_exchange_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:go_router/go_router.dart';

/// Renders whichever error the order creation failed with. Amount limits get
/// the amount appended, everything else falls back to its translation so that
/// the Continue button is never silently dead.
class _CreateOrderError extends StatelessWidget {
  const _CreateOrderError({required this.error});

  final BuyError error;

  @override
  Widget build(BuildContext context) {
    final errorStyle = context.font.bodyMedium?.copyWith(
      color: context.appColors.error,
    );

    final (String label, double amount, String currency)? limit =
        switch (error) {
          BelowMinAmountBuyError(:final minAmount, :final currency) => (
            context.loc.buyInputMinAmountError,
            minAmount,
            currency,
          ),
          AboveMaxAmountBuyError(:final maxAmount, :final currency) => (
            context.loc.buyInputMaxAmountError,
            maxAmount,
            currency,
          ),
          _ => null,
        };

    if (limit == null) {
      return Center(
        child: Text(
          error.toTranslated(context),
          style: errorStyle,
          textAlign: .center,
        ),
      );
    }

    final (label, amount, currency) = limit;
    // The api denominates a limit either in fiat or in bitcoin; only the latter
    // can be shown in the user's bitcoin unit.
    final isBitcoinLimit = currency == 'BTC' || currency == 'LBTC';
    return Row(
      mainAxisAlignment: .center,
      children: [
        Text(label, style: errorStyle),
        const Gap(4),
        if (isBitcoinLimit)
          CurrencyText(
            ConvertAmount.btcToSats(amount),
            showFiat: false,
            style: errorStyle,
            overrideHideAmounts: true,
          )
        else
          Text(FormatAmount.fiat(amount, currency), style: errorStyle),
      ],
    );
  }
}

class BuyInputScreen extends StatefulWidget {
  const BuyInputScreen({super.key});

  @override
  State<BuyInputScreen> createState() => _BuyInputScreenState();
}

class _BuyInputScreenState extends State<BuyInputScreen> {
  final FocusNode _amountNode = FocusNode();

  @override
  void dispose() {
    _amountNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStarted = context.select((BuyBloc bloc) => bloc.state.isStarted);
    final canCreateOrder = context.select(
      (BuyBloc bloc) => bloc.state.canCreateOrder,
    );
    final isCreatingOrder = context.select(
      (BuyBloc bloc) => bloc.state.isCreatingOrder,
    );
    final createOrderError = context.select(
      (BuyBloc bloc) => bloc.state.createOrderBuyError,
    );
    final needsKycUpgrade = context.select(
      (BuyBloc bloc) => bloc.state.needsKycUpgrade(bloc.state.amount ?? 0),
    );
    final showInsufficientBalanceError = context.select(
      (BuyBloc bloc) => bloc.state.showInsufficientBalanceError,
    );
    final canOfferPayjoin = context.select(
      (BuyBloc bloc) => bloc.state.canOfferPayjoin,
    );
    final isPayjoinEnabled = context.select(
      (BuyBloc bloc) => bloc.state.isPayjoinEnabled,
    );

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
        title: Text(context.loc.buyInputTitle),
      ),
      body: SafeArea(
        child: BBKeyboardActions(
          disableScroll: true,
          focusNodes: [_amountNode],
          child: ScrollableColumn(
            crossAxisAlignment: .start,
            children: [
              const Gap(24),
              BuyAmountInputFields(focusNode: _amountNode),
              const Gap(16.0),
              const BuyDestinationInputFields(),
              if (canOfferPayjoin) ...[
                const Gap(16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.loc.payjoinUseToggle,
                        style: context.font.bodyMedium,
                      ),
                    ),
                    BBSwitch(
                      value: isPayjoinEnabled,
                      onChanged: isCreatingOrder
                          ? null
                          : (enabled) => context.read<BuyBloc>().add(
                              BuyEvent.payjoinToggled(enabled),
                            ),
                    ),
                  ],
                ),
              ],
              const Spacer(),
              Column(
                mainAxisSize: .min,
                children: [
                  if (isCreatingOrder)
                    const Center(child: CircularProgressIndicator()),
                  if (createOrderError != null)
                    _CreateOrderError(error: createOrderError),

                  const Gap(16),
                  if (isStarted) ...[
                    if (needsKycUpgrade) ...[
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
                            FundExchangeRoute.fundExchange.name,
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
                    const LoadingLineContent(
                      height: 56,
                      width: double.infinity,
                    ),
                  ],
                  const Gap(16.0),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
