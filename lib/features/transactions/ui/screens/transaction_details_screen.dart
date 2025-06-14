import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/sender_broadcast_payjoin_original_tx_button.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_details_table.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_label_bottomsheet.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/ui/components/badges/transaction_direction_badge.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class TransactionDetailsScreen extends StatelessWidget {
  const TransactionDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tx = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.transaction,
    );
    final state = context.select((TransactionDetailsCubit bloc) => bloc.state);
    final amountSat = tx.amountSat;
    final isIncoming = tx.isIncoming;
    final isOngoingSenderPayjoin =
        context.select(
          (TransactionDetailsCubit bloc) => bloc.state.isOngoingPayjoin,
        ) &&
        tx.isOutgoing == true;
    final isOrderType = tx.isOrder && tx.order != null;
    final orderAmountAndCurrency = tx.order?.amountAndCurrencyToDisplay();
    final showOrderInFiat =
        isOrderType &&
        (tx.order is FiatPaymentOrder ||
            tx.order is BalanceAdjustmentOrder ||
            tx.order is WithdrawOrder);

    bool isOrderIncoming = false;
    if (isOrderType) {
      final orderType = tx.order?.orderType;
      switch (orderType) {
        case OrderType.buy:
        case OrderType.funding:
        case OrderType.balanceAdjustment:
        case OrderType.refund:
          isOrderIncoming = true;
        case OrderType.sell:
        case OrderType.withdraw:
        case OrderType.fiatPayment:
          isOrderIncoming = false;
        default:
          isOrderIncoming = isIncoming;
      }
    } else {
      isOrderIncoming = isIncoming;
    }

    final swap = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.swap,
    );
    final swapAction = swap?.swapAction ?? '';
    final isChainSwap = swap?.isChainSwap ?? false;
    final retryingSwap = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.retryingSwap,
    );
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Transaction details',
          actionIcon: Icons.close,
          onAction: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(WalletRoute.walletHome.name);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              children: [
                TransactionDirectionBadge(
                  isIncoming: isOrderIncoming,
                  isSwap: isChainSwap,
                ),
                const Gap(24),
                BBText(
                  (swap != null && swap.swapCompleted && swap.isChainSwap)
                      ? 'Swap Completed'
                      : (swap != null &&
                          swap.swapInProgress &&
                          swap.isChainSwap)
                      ? 'Swap In Progress'
                      : (swap != null &&
                          swap.swapInProgress &&
                          (swap.isLnSendSwap || swap.isLnReceiveSwap))
                      ? 'Payment In Progress'
                      : swap != null && swap.swapRefunded
                      ? 'Payment Refunded'
                      : isOrderType && tx.order != null
                      ? tx.order!.orderType.value
                      : isOngoingSenderPayjoin
                      ? 'Payjoin requested'
                      : isIncoming
                      ? 'Payment received'
                      : 'Payment sent',
                  style: context.font.headlineLarge,
                ),
                const Gap(8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CurrencyText(
                      isOrderType &&
                              !showOrderInFiat &&
                              orderAmountAndCurrency != null
                          ? orderAmountAndCurrency.$1.toInt()
                          : amountSat,
                      showFiat: false,
                      style: context.font.displaySmall?.copyWith(
                        color: theme.colorScheme.outlineVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      fiatAmount:
                          isOrderType &&
                                  showOrderInFiat &&
                                  orderAmountAndCurrency != null
                              ? orderAmountAndCurrency.$1.toDouble()
                              : null,
                      fiatCurrency:
                          isOrderType &&
                                  showOrderInFiat &&
                                  orderAmountAndCurrency != null
                              ? orderAmountAndCurrency.$2
                              : null,
                    ),
                  ],
                ),
                const Gap(24),
                if (swap != null && (swap.requiresAction)) ...[
                  BBButton.big(
                    disabled: retryingSwap,
                    label: 'Retry Swap $swapAction',
                    onPressed: () async {
                      await context.read<TransactionDetailsCubit>().processSwap(
                        swap,
                      );
                    },
                    bgColor: theme.colorScheme.primary,
                    textColor: theme.colorScheme.onPrimary,
                  ),
                  const Gap(24),
                ],
                const TransactionDetailsTable(),
                if (isOngoingSenderPayjoin) ...[
                  const Gap(24),
                  const SenderBroadcastPayjoinOriginalTxButton(),
                  const Gap(24),
                ] else ...[
                  const Gap(64),
                ],

                BBButton.big(
                  label: 'Add note',
                  disabled:
                      !(state.walletTransaction?.labels.length != null &&
                          state.walletTransaction!.labels.length < 10),
                  onPressed: () async {
                    if (state.walletTransaction?.labels.length != null &&
                        state.walletTransaction!.labels.length < 10) {
                      await showTransactionLabelBottomSheet(context);
                    } else {
                      log.warning(
                        'A transaction can have up to 10 labels, current length: ${state.walletTransaction?.labels.length}',
                      );
                    }
                  },
                  bgColor: Colors.transparent,
                  textColor: theme.colorScheme.secondary,
                  outlined: true,
                  borderColor: theme.colorScheme.secondary,
                ),
                const Gap(16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
