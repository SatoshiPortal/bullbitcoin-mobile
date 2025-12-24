import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/widgets/badges/transaction_direction_badge.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/buy/ui/buy_router.dart';
import 'package:bb_mobile/features/buy/ui/widgets/accelerate_transaction_list_tile.dart';
import 'package:bb_mobile/features/replace_by_fee/router.dart';
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
    final returnHome =
        GoRouterState.of(context).uri.queryParameters['returnHome'] == 'true';
    final isLoading = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.isLoading,
    );
    final tx = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.transaction,
    );
    final wallet = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.wallet,
    );
    final isPayjoinCompleted = context.select(
      (TransactionDetailsCubit bloc) =>
          bloc.state.payjoin?.status == PayjoinStatus.completed,
    );
    final isBroadcastingPayjoinOriginalTx = context.select(
      (TransactionDetailsCubit bloc) =>
          bloc.state.isBroadcastingPayjoinOriginalTx,
    );

    final isOutgoing = tx?.isOutgoing;
    final isIncoming = tx?.isIncoming;
    final isOngoingSwap = tx?.isOngoingSwap;
    final isOrderType = tx?.isOrder == true;
    final walletTransaction = tx?.walletTransaction;
    final swap = tx?.swap;
    final swapAction = swap?.swapAction(context) ?? '';
    final isChainSwap = swap?.isChainSwap ?? false;
    final retryingSwap = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.retryingSwap,
    );
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: isOngoingSwap == true
              ? (isChainSwap
                    ? context.loc.transactionDetailTransferProgress
                    : context.loc.transactionDetailSwapProgress)
              : context.loc.transactionDetailTitle,
          actionIcon: Icons.close,
          onAction: () {
            if (returnHome) {
              context.goNamed(WalletRoute.walletHome.name);
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(WalletRoute.walletHome.name);
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3.0),
          child: FadingLinearProgress(
            trigger: isBroadcastingPayjoinOriginalTx,
            backgroundColor: context.appColors.onPrimary,
            foregroundColor: context.appColors.primary,
          ),
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
                if (isOngoingSwap == true && swap != null) ...[
                  const Gap(8),
                  SwapProgressIndicator(swap: swap),
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
                if (isOngoingSwap == true && swap != null) ...[
                  SwapStatusDescription(swap: swap),
                  const Gap(16),
                ],
                if (isOrderType &&
                    tx?.isBuyOrder == true &&
                    tx?.order != null &&
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
                if (swap != null && swap.requiresAction) ...[
                  const Gap(16),
                  BBButton.big(
                    disabled: retryingSwap,
                    label: isChainSwap
                        ? context.loc.transactionDetailRetryTransfer(swapAction)
                        : context.loc.transactionDetailRetrySwap(swapAction),
                    onPressed: () async {
                      await context.read<TransactionDetailsCubit>().processSwap(
                        swap,
                      );
                    },
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                  ),
                ],
                const Gap(32),
                if (tx?.isOngoingPayjoinSender == true &&
                    !isPayjoinCompleted) ...[
                  const SenderBroadcastPayjoinOriginalTxButton(),
                  const Gap(24),
                ],
                if (isLoading)
                  const LoadingLineContent(height: 40)
                else
                  BBButton.big(
                    label: context.loc.transactionDetailAddNote,
                    disabled:
                        !(walletTransaction != null &&
                            walletTransaction.labels.length < 10),
                    onPressed: () async {
                      if (walletTransaction != null &&
                          walletTransaction.labels.length < 10) {
                        await showTransactionLabelBottomSheet(context);
                      } else {
                        log.warning(
                          'A transaction can have up to 10 labels, current length: ${walletTransaction?.labels.length}',
                        );
                      }
                    },
                    bgColor: context.appColors.transparent,
                    textColor: context.appColors.onSurface,
                    outlined: true,
                    borderColor: context.appColors.onSurface,
                  ),
                const Gap(16),
                if (isOutgoing == true &&
                    walletTransaction?.isConfirmed == false &&
                    walletTransaction?.isRbf == true &&
                    walletTransaction?.isBitcoin == true &&
                    wallet?.signsLocally == true &&
                    tx?.txId != null &&
                    swap == null)
                  BBButton.big(
                    label: context.loc.transactionDetailAccelerate,
                    onPressed: () {
                      context.pushNamed(
                        ReplaceByFeeRoute.replaceByFeeFlow.name,
                        extra: walletTransaction,
                      );
                    },
                    bgColor: context.appColors.onSurface,
                    textColor: context.appColors.surface,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
