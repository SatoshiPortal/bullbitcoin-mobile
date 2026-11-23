import 'package:bb_mobile/features/buy/ui/widgets/buy_order_failure_message.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/widgets/buy_amount_input_fields.dart';
import 'package:bb_mobile/features/buy/ui/widgets/buy_destination_input_fields.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bb_mobile/features/fund_exchange/public/fund_exchange_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullKeyboardActions,
        BullButton,
        BullInfoCard,
        BullScrollableColumn,
        BullShimmerLine,
        BullSwitch,
        Gap,
        BullTypographyX;
import 'package:go_router/go_router.dart';

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
      (BuyBloc bloc) => bloc.state.inputFailure,
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
        child: BullKeyboardActions(
          doneText: context.loc.doneButton,
          disableScroll: true,
          child: BullScrollableColumn(
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
                        style: context.bullType.body,
                      ),
                    ),
                    BullSwitch(
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
                  if (createOrderError != null)
                    BuyOrderFailureMessage(error: createOrderError),

                  const Gap(16),
                  if (isStarted) ...[
                    if (needsKycUpgrade) ...[
                      BullInfoCard(
                        title: context.loc.buyInputKycPending,
                        description: context.loc.buyInputKycMessage,
                        bgColor: context.appColors.tertiary.withValues(
                          alpha: 0.1,
                        ),
                        tagColor: context.appColors.onTertiary,
                      ),
                      const Gap(16.0),
                      BullButton.primary(
                        label: context.loc.buyInputCompleteKyc,
                        onPressed: () {
                          context.pushReplacementNamed(
                            BullExchangeNavigation.kycName,
                          );
                        },
                      ),
                    ] else if (showInsufficientBalanceError) ...[
                      BullInfoCard(
                        title: context.loc.buyInputInsufficientBalance,
                        description:
                            context.loc.buyInputInsufficientBalanceMessage,
                        bgColor: context.appColors.tertiary.withValues(
                          alpha: 0.1,
                        ),
                        tagColor: context.appColors.onTertiary,
                      ),
                      const Gap(16.0),
                      BullButton.primary(
                        label: context.loc.buyInputFundAccount,
                        onPressed: () {
                          context.pushReplacementNamed(
                            FundExchangeRoute.fundExchange.name,
                          );
                        },
                      ),
                    ] else
                      BullButton.primary(
                        label: context.loc.buyInputContinue,
                        onPressed: (!canCreateOrder || isCreatingOrder)
                            ? null
                            : () {
                                context.read<BuyBloc>().add(
                                  const BuyEvent.createOrder(),
                                );
                              },
                      ),
                  ] else ...[
                    const BullShimmerLine(height: 56, width: double.infinity),
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
