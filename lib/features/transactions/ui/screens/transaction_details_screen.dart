import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/widgets/badges/transaction_direction_badge.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/buy/ui/buy_router.dart';
import 'package:bb_mobile/features/buy/ui/widgets/accelerate_transaction_list_tile.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/sender_broadcast_payjoin_original_tx_button.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/swap_progress_indicator.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/swap_status_description.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_details_amount.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_details_status_label.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_details_table.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_label_bottomsheet.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class TransactionDetailsScreen extends StatelessWidget {
  const TransactionDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.isLoading,
    );
    final tx = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.transaction,
    );

    final isIncoming = tx?.isIncoming;
    final isOngoingSwap = tx?.isOngoingSwap;
    final isOrderType = tx?.isOrder == true;
    final walletTransaction = tx?.walletTransaction;
    final swap = tx?.swap;
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
          title:
              isOngoingSwap == true ? 'Swap Progress' : 'Transaction details',
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
                if (isLoading)
                  const LoadingBoxContent(height: 72, width: 72)
                else
                  TransactionDirectionBadge(
                    isIncoming: isIncoming ?? false,
                    isSwap: isChainSwap,
                  ),
                const Gap(24),
                if (isLoading)
                  const LoadingLineContent(width: 150)
                else
                  const TransactionDetailsStatusLabel(),
                if (isOngoingSwap == true) ...[
                  const Gap(8),
                  SwapProgressIndicator(swap: swap!),
                ],
                if (isLoading)
                  const LoadingLineContent(
                    height: 24,
                    width: 200,
                    padding: EdgeInsets.zero,
                  )
                else
                  const TransactionDetailsAmount(),
                const Gap(16),
                if (swap != null && swap.requiresAction) ...[
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
                  const Gap(16),
                ],
                if (isOngoingSwap == true && swap != null) ...[
                  SwapStatusDescription(swap: swap),
                  const Gap(16),
                ],
                if (isOrderType &&
                    tx?.isBuyOrder == true &&
                    (tx!.order! as BuyOrder).bitcoinAddress != null &&
                    tx.order!.sentAt == null) ...[
                  AccelerateTransactionListTile(
                    orderId: tx.order!.orderId,
                    onTap: () {
                      context.pushNamed(
                        BuyRoute.buyAccelerate.name,
                        pathParameters: {'orderId': tx.order!.orderId},
                      );
                    },
                  ),
                  const Gap(16),
                ],
                if (isLoading)
                  const LoadingBoxContent(height: 400)
                else
                  const TransactionDetailsTable(),
                const Gap(32),
                if (tx?.isOngoingPayjoinSender == true) ...[
                  const SenderBroadcastPayjoinOriginalTxButton(),
                  const Gap(24),
                ],
                if (isLoading)
                  const LoadingLineContent(height: 40)
                else
                  BBButton.big(
                    label: 'Add note',
                    disabled:
                        !(walletTransaction?.labels.length != null &&
                            walletTransaction!.labels.length < 10),
                    onPressed: () async {
                      if (walletTransaction?.labels.length != null &&
                          walletTransaction!.labels.length < 10) {
                        await showTransactionLabelBottomSheet(context);
                      } else {
                        log.warning(
                          'A transaction can have up to 10 labels, current length: ${walletTransaction?.labels.length}',
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
