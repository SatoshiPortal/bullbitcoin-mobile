import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/widgets/buy_order_failure_message.dart';
import 'package:bb_mobile/features/buy/ui/buy_payout_method_label.dart';
import 'package:bb_mobile/features/buy/ui/widgets/buy_confirm_detail_row.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAsyncStatus,
        BullButton,
        BullCountdown,
        BullShimmerLine,
        BullText,
        Gap;

class BuyConfirmScreen extends StatelessWidget {
  const BuyConfirmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BuyBloc>().state;
    final buyOrder = state.buyOrder;
    final isLoading = state.isCreatingOrder || state.isRefreshingOrder;
    final isUnavailable = buyOrder == null && state.confirmFailure != null;
    final formattedPayInAmount = buyOrder == null || isLoading
        ? null
        : FormatAmount.fiat(buyOrder.payinAmount, buyOrder.payinCurrency);
    final bitcoinUnit = context.select(
      (SettingsCubit cubit) => cubit.state.bitcoinUnit,
    );
    final formattedPayOutAmount = buyOrder == null || isLoading
        ? null
        : bitcoinUnit == BitcoinUnit.sats
        ? FormatAmount.sats(ConvertAmount.btcToSats(buyOrder.payoutAmount))
        : FormatAmount.btc(buyOrder.payoutAmount);
    final formattedExchangeRate = buyOrder == null || isLoading
        ? null
        : FormatAmount.fiat(
            buyOrder.exchangeRateAmount ??
                (buyOrder.payoutAmount > 0
                    ? buyOrder.payinAmount / buyOrder.payoutAmount
                    : 0.0),
            buyOrder.exchangeRateCurrency ?? buyOrder.payinCurrency,
          );
    final externalBitcoinWalletLabel = context.loc.buyConfirmExternalWallet;
    final selectedWallet = context.select(
      (BuyBloc bloc) => bloc.state.selectedWallet,
    );
    final payoutWallet = selectedWallet == null
        ? externalBitcoinWalletLabel
        : selectedWallet.displayLabel(context);
    // With no wallet of ours selected the payout goes to an address the user
    // pasted, so the order itself is the only source for the network.
    final payoutMethod = buyPayoutMethodLabel(
      context,
      isLiquid: selectedWallet?.network.isLiquid ?? buyOrder?.isLiquid ?? false,
    );

    final isConfirmingOrder = state.isConfirmingOrder;
    final confirmFailure = state.confirmFailure;
    final isRefreshingOrder = state.isRefreshingOrder;
    return PopScope<Object?>(
      canPop: !isConfirmingOrder,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          context.read<BuyBloc>().add(const BuyEvent.orderCreationAbandoned());
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(context.loc.buyConfirmTitle)),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: context.appColors.secondaryFixedDim,
                        shape: .circle,
                      ),
                      child: Image.asset(Assets.icons.btc.path),
                    ),
                  ),
                  const Gap(13),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Center(
                      child: switch (formattedPayInAmount) {
                        final String amount => BullText(
                          amount,
                          style: context.font.displaySmall,
                          color: context.appColors.secondary,
                        ),
                        null when isUnavailable => const Text('—'),
                        null => const BullShimmerLine(
                          width: 180,
                          height: 32,
                          padding: EdgeInsets.zero,
                        ),
                      },
                    ),
                  ),
                  const Gap(32),
                  BuyConfirmDetailRow(
                    label: context.loc.buyConfirmYouPay,
                    value: formattedPayInAmount,
                    isUnavailable: isUnavailable,
                  ),
                  BuyConfirmDetailRow(
                    label: context.loc.buyConfirmYouReceive,
                    value: formattedPayOutAmount,
                    isUnavailable: isUnavailable,
                  ),
                  BuyConfirmDetailRow(
                    label: context.loc.buyConfirmBitcoinPrice,
                    value: formattedExchangeRate,
                    isUnavailable: isUnavailable,
                  ),
                  BuyConfirmDetailRow(
                    label: context.loc.buyConfirmPayoutWallet,
                    value: payoutWallet,
                  ),
                  BuyConfirmDetailRow(
                    label: context.loc.buyConfirmPayoutMethod,
                    value: payoutMethod,
                  ),
                  const Gap(32),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: .min,
              children: [
                // The countdown keeps its place while a refresh is in flight:
                // remounting it on an expired quote fires its timeout again,
                // and each refresh then asked for the next one.
                if (buyOrder != null)
                  Visibility(
                    visible: !isConfirmingOrder,
                    maintainState: true,
                    child: Row(
                      mainAxisAlignment: .center,
                      children: [
                        Text(
                          context.loc.buyConfirmAwaitingConfirmation,
                          style: context.font.bodyMedium?.copyWith(
                            fontWeight: .w500,
                            color: context.appColors.outline,
                          ),
                        ),
                        const Gap(4),
                        if (buyOrder.confirmationDeadline case final deadline?)
                          _QuoteCountdown(
                            orderId: buyOrder.orderId,
                            deadline: deadline,
                          ),
                      ],
                    ),
                  )
                else if (isLoading)
                  const BullShimmerLine(
                    width: 160,
                    height: 14,
                    padding: EdgeInsets.zero,
                  ),
                if (confirmFailure != null) ...[
                  const Gap(16),
                  BuyOrderFailureMessage(error: confirmFailure),
                ],
                const Gap(16),
                if (isConfirmingOrder)
                  BullAsyncStatus.progress(
                    label: context.loc.buyConfirmAwaitingConfirmation,
                    color: context.appColors.secondary,
                    textStyle: context.font.bodyMedium,
                  )
                else
                  BullButton.big(
                    label: context.loc.buyConfirmPurchase,
                    disabled:
                        buyOrder == null ||
                        isConfirmingOrder ||
                        isRefreshingOrder ||
                        isLoading,
                    onPressed: () {
                      context.read<BuyBloc>().add(
                        const BuyEvent.confirmOrder(),
                      );
                    },
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for a fresh quote once per expired deadline of the order on screen.
class _QuoteCountdown extends StatefulWidget {
  const _QuoteCountdown({required this.orderId, required this.deadline});

  final String orderId;
  final DateTime deadline;

  @override
  State<_QuoteCountdown> createState() => _QuoteCountdownState();
}

class _QuoteCountdownState extends State<_QuoteCountdown> {
  (String, DateTime)? _refreshedFor;

  void _onTimeout() {
    final bloc = context.read<BuyBloc>();
    final state = bloc.state;
    final key = (widget.orderId, widget.deadline);
    // A confirmed purchase has no quote left to refresh, and a refresh already
    // in flight will bring the latest order anyway.
    if (_refreshedFor == key ||
        state.isConfirmingOrder ||
        state.isRefreshingOrder ||
        state.buyOrder?.isPayinCompleted == true) {
      return;
    }
    _refreshedFor = key;
    bloc.add(const BuyEvent.refreshOrder());
  }

  @override
  Widget build(BuildContext context) =>
      BullCountdown(until: widget.deadline, onTimeout: _onTimeout);
}
