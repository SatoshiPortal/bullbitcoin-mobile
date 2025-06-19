import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
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
    final isOngoingSwap = tx.isOngoingSwap;
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
          title: isOngoingSwap ? 'Swap Progress' : 'Transaction details',
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
                      : swap != null &&
                          (swap.status == SwapStatus.failed ||
                              swap.status == SwapStatus.expired)
                      ? swap.status == SwapStatus.failed
                          ? 'Swap Failed'
                          : 'Swap Expired'
                      : isOrderType && tx.order != null
                      ? tx.order!.orderType.value
                      : isOngoingSenderPayjoin
                      ? 'Payjoin requested'
                      : isIncoming
                      ? 'Payment received'
                      : 'Payment sent',
                  style: context.font.headlineLarge?.copyWith(
                    color:
                        swap != null &&
                                (swap.status == SwapStatus.failed ||
                                    swap.status == SwapStatus.expired)
                            ? swap.status == SwapStatus.failed
                                ? context.colour.error
                                : context.colour.error.withValues(alpha: 0.7)
                            : null,
                  ),
                ),
                if (isOngoingSwap && swap != null) ...[
                  const Gap(8),
                  _SwapProgressIndicator(swap: swap),
                ],
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
                if (isOngoingSwap && swap != null) ...[
                  const Gap(16),
                  _SwapStatusDescription(swap: swap),
                  const Gap(16),
                ],
                const TransactionDetailsTable(),
                if (isOngoingSenderPayjoin) ...[
                  const Gap(24),
                  const SenderBroadcastPayjoinOriginalTxButton(),
                  const Gap(24),
                ] else if (!isOngoingSwap) ...[
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

class _SwapProgressIndicator extends StatelessWidget {
  const _SwapProgressIndicator({required this.swap});

  final Swap swap;

  @override
  Widget build(BuildContext context) {
    final steps = _getProgressSteps();
    final currentStep = _getCurrentStep();
    final isFailedOrExpired =
        swap.status == SwapStatus.failed || swap.status == SwapStatus.expired;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          SizedBox(
            height: 100,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double totalWidth = constraints.maxWidth;
                final double stepWidth = totalWidth / steps.length;

                return Stack(
                  children: [
                    // Connector line background (gray line across entire width)
                    Positioned(
                      top: 20,
                      left: stepWidth / 2,
                      right: stepWidth / 2,
                      child: Container(
                        height: 5,
                        color: context.colour.surfaceContainerHighest,
                      ),
                    ),

                    // Active connector line (colored line up to current step)
                    if (!isFailedOrExpired && currentStep > 0)
                      Positioned(
                        top: 20,
                        left: stepWidth / 2,
                        width: stepWidth * currentStep,
                        child: Container(
                          height: 5,
                          color: context.colour.primary,
                        ),
                      ),

                    // Step indicators and labels
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(steps.length, (index) {
                        final isCompleted =
                            index <= currentStep && !isFailedOrExpired;
                        final isCurrent =
                            index == currentStep && !isFailedOrExpired;

                        // Determine colors based on state
                        final Color indicatorColor;
                        if (isFailedOrExpired && index == 0) {
                          indicatorColor = context.colour.error;
                        } else if (isCompleted) {
                          indicatorColor = context.colour.primary;
                        } else {
                          indicatorColor =
                              context.colour.surfaceContainerHighest;
                        }

                        // Create indicator content
                        Widget? indicatorChild;
                        if (isFailedOrExpired && index == 0) {
                          indicatorChild = Icon(
                            Icons.error_outline,
                            size: 15,
                            color: context.colour.onError,
                          );
                        } else if (isCompleted) {
                          indicatorChild = Icon(
                            Icons.check,
                            size: 20,
                            color: context.colour.onPrimary,
                          );
                        } else {
                          indicatorChild = Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: context.colour.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          );
                        }

                        return Expanded(
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: indicatorColor,
                                      shape: BoxShape.circle,
                                      border:
                                          isCurrent
                                              ? Border.all(
                                                color: context.colour.secondary,
                                                width: 2,
                                              )
                                              : null,
                                    ),
                                    child: Center(child: indicatorChild),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                steps[index],
                                style: TextStyle(
                                  color: _getStepLabelColor(
                                    context,
                                    index,
                                    currentStep,
                                  ),
                                  fontSize: 11,
                                  fontWeight:
                                      isCompleted
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getProgressSteps() {
    if (swap is LnReceiveSwap) {
      return ['Initiated', 'Payment\nReceived', 'Funds\nClaimed'];
    } else if (swap is LnSendSwap) {
      // For Bitcoin/Liquid to Lightning swaps
      // pending -> paid -> completed
      // Initiated: Transaction created but not confirmed
      // Transaction Confirmed: Transaction confirmed, funds are secured (paid status)
      // Payment Sent: Lightning payment sent, swap completed (completed status)
      return ['Initiated', 'Transaction\nConfirmed', 'Payment\nSent'];
    } else if (swap is ChainSwap) {
      // For Bitcoin to Liquid or Liquid to Bitcoin swaps
      // pending -> paid -> claimable -> completed
      return ['Initiated', 'Confirmed', 'Counterparty', 'Completed'];
    }
    return ['Initiated', 'In Progress', 'Completed'];
  }

  int _getCurrentStep() {
    if (swap.status == SwapStatus.failed || swap.status == SwapStatus.expired) {
      return -1; // Special case for failed/expired
    }

    return switch (swap.status) {
      SwapStatus.pending => 0,
      SwapStatus.paid => 1,
      SwapStatus.claimable => swap is ChainSwap ? 2 : 1,
      SwapStatus.refundable => swap is ChainSwap ? 2 : 1,
      SwapStatus.canCoop => swap is ChainSwap ? 2 : 1,
      SwapStatus.completed => swap is ChainSwap ? 3 : 2,
      SwapStatus.failed || SwapStatus.expired => 0,
    };
  }

  Color _getStepLabelColor(BuildContext context, int index, int currentStep) {
    final isFailedOrExpired =
        swap.status == SwapStatus.failed || swap.status == SwapStatus.expired;

    if (isFailedOrExpired) {
      return index == 0 ? context.colour.error : context.colour.outline;
    }

    if (index <= currentStep) {
      return context.colour.primary;
    }

    return context.colour.outline;
  }
}

class _SwapStatusDescription extends StatelessWidget {
  const _SwapStatusDescription({required this.swap});

  final Swap swap;

  @override
  Widget build(BuildContext context) {
    final bool isFailedOrExpired =
        swap.status == SwapStatus.failed || swap.status == SwapStatus.expired;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isFailedOrExpired
                ? context.colour.errorContainer.withValues(alpha: 0.15)
                : context.colour.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isFailedOrExpired
                  ? context.colour.error.withValues(alpha: 0.5)
                  : context.colour.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                swap.status == SwapStatus.failed ||
                        swap.status == SwapStatus.expired
                    ? Icons.warning_amber_rounded
                    : Icons.info_outline,
                size: 20,
                color:
                    swap.status == SwapStatus.failed ||
                            swap.status == SwapStatus.expired
                        ? context.colour.error
                        : context.colour.secondary,
              ),
              const Gap(8),
              BBText(
                swap.status == SwapStatus.failed
                    ? 'Swap Failed'
                    : swap.status == SwapStatus.expired
                    ? 'Swap Expired'
                    : 'Swap Status',
                style: context.font.titleSmall?.copyWith(
                  color:
                      swap.status == SwapStatus.failed ||
                              swap.status == SwapStatus.expired
                          ? context.colour.error
                          : context.colour.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Gap(8),
          BBText(
            _getSwapStatusDescription(),
            style: context.font.bodySmall?.copyWith(
              color:
                  swap.status == SwapStatus.failed ||
                          swap.status == SwapStatus.expired
                      ? context.colour.error
                      : context.colour.onSurfaceVariant,
            ),
          ),
          if (_getAdditionalInfo().isNotEmpty) ...[
            const Gap(12),
            BBText(
              _getAdditionalInfo(),
              style: context.font.bodySmall?.copyWith(
                color:
                    swap.status == SwapStatus.failed ||
                            swap.status == SwapStatus.expired
                        ? context.colour.error.withValues(alpha: 0.8)
                        : context.colour.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getSwapStatusDescription() {
    if (swap is LnReceiveSwap) {
      switch (swap.status) {
        case SwapStatus.pending:
          return 'Your swap has been initiated. We are waiting for a payment to be received on the Lightning Network.';
        case SwapStatus.paid:
          return 'Payment has been received! We are now broadcasting the on-chain transaction to your wallet.';
        case SwapStatus.claimable:
          return 'The on-chain transaction has been confirmed. We are now claiming the funds to complete your swap.';
        case SwapStatus.completed:
          return 'Your swap has been completed successfully! The funds should now be available in your wallet.';
        case SwapStatus.failed:
          return 'There was an issue with your swap. Please contact support if funds have not been returned within 24 hours.';
        case SwapStatus.expired:
          return 'This swap has expired. Any funds sent will be automatically returned to the sender.';
        default:
          return 'Your swap is in progress. This process is automated and may take some time to complete.';
      }
    } else if (swap is LnSendSwap) {
      switch (swap.status) {
        case SwapStatus.pending:
          return 'Your swap has been initiated. We are broadcasting the on-chain transaction to lock your funds.';
        case SwapStatus.paid:
          return 'Your on-chain transaction has been confirmed. We are now preparing to send the Lightning payment.';
        case SwapStatus.completed:
          return 'The Lightning payment has been sent successfully! Your swap is now complete.';
        case SwapStatus.failed:
          return 'There was an issue with your swap. Your funds will be returned to your wallet automatically.';
        case SwapStatus.expired:
          return 'This swap has expired. Your funds will be automatically returned to your wallet.';
        default:
          return 'Your swap is in progress. This process is automated and may take some time to complete.';
      }
    } else if (swap is ChainSwap) {
      switch (swap.status) {
        case SwapStatus.pending:
          return swap.type == SwapType.bitcoinToLiquid
              ? 'Your swap has been initiated. We are broadcasting your Bitcoin transaction to start the swap process.'
              : 'Your swap has been initiated. We are broadcasting your Liquid transaction to start the swap process.';
        case SwapStatus.paid:
          return 'Your transaction has been confirmed. We are now waiting for the counterparty transaction to be detected.';
        case SwapStatus.claimable:
          return 'The counterparty transaction has been detected. We are now claiming the funds to complete your swap.';
        case SwapStatus.refundable:
          return 'The swap can be refunded. Your funds will be returned to your wallet automatically.';
        case SwapStatus.completed:
          return 'Your swap has been completed successfully! The funds should now be available in your wallet.';
        case SwapStatus.failed:
          return 'There was an issue with your swap. Please contact support if funds have not been returned within 24 hours.';
        case SwapStatus.expired:
          return 'This swap has expired. Your funds will be automatically returned to your wallet.';
        default:
          return 'Your swap is in progress. This process is automated and may take some time to complete.';
      }
    }
    return 'Your swap is in progress. This process is automated and may take some time to complete.';
  }

  String _getAdditionalInfo() {
    if (swap.status == SwapStatus.failed || swap.status == SwapStatus.expired) {
      return 'If you have any questions or concerns, please contact support for assistance.';
    }

    if (swap is ChainSwap &&
        (swap.status == SwapStatus.pending || swap.status == SwapStatus.paid)) {
      return 'On-chain swaps may take some time to complete due to blockchain confirmation times. Please be patient.';
    }

    if (swap.status == SwapStatus.pending ||
        swap.status == SwapStatus.paid ||
        swap.status == SwapStatus.claimable) {
      return 'You can safely close this screen. The swap will continue processing in the background.';
    }

    return '';
  }
}
