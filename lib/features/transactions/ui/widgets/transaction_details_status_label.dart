import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransactionDetailsStatusLabel extends StatelessWidget {
  const TransactionDetailsStatusLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final transaction = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.transaction,
    );
    final swap = transaction?.swap;
    final orderSwap = transaction?.orderSwap;
    final order = transaction?.order;
    final isOrder = transaction?.isOrder;
    // Display status, not the raw session status: derived from the broadcast
    // transaction when it is already visible, so a stale session row
    // (completion detection lagging on a background poll) can't surface
    // "requested"/"proposed" for a payment that's already on-chain.
    final payjoinStatus = context.select(
      (TransactionDetailsCubit bloc) =>
          bloc.state.transaction?.displayPayjoinStatus,
    );

    final label = orderSwap != null
        ? switch (orderSwap.localStatus) {
            OrderSwapLocalStatus.completed =>
              context.loc.coreSwapsStatusCompleted,
            OrderSwapLocalStatus.refunded =>
              context.loc.transactionStatusPaymentRefunded,
            OrderSwapLocalStatus.failed =>
              context.loc.transactionStatusSwapFailed,
            OrderSwapLocalStatus.expired =>
              context.loc.transactionStatusSwapExpired,
            _ => context.loc.transactionStatusPaymentInProgress,
          }
        : (swap != null && swap.swapCompleted && swap.isChainSwap)
          ? context.loc.transactionStatusTransferCompleted
          : (swap != null && swap.swapInProgress && swap.isChainSwap)
          ? context.loc.transactionStatusTransferInProgress
          : (swap != null &&
                swap.swapInProgress &&
                (swap.isLnSendSwap || swap.isLnReceiveSwap))
          ? context.loc.transactionStatusPaymentInProgress
          : swap != null && swap.swapRefunded
          ? context.loc.transactionStatusPaymentRefunded
          : swap != null &&
                (swap.status == SwapStatus.failed ||
                    swap.status == SwapStatus.expired)
          ? swap.status == SwapStatus.failed
                ? (swap.isChainSwap
                      ? context.loc.transactionStatusTransferFailed
                      : context.loc.transactionStatusSwapFailed)
                : (swap.isChainSwap
                      ? context.loc.transactionStatusTransferExpired
                      : context.loc.transactionStatusSwapExpired)
          : isOrder == true && order != null
          ? order.orderType.value
          : payjoinStatus == PayjoinStatus.completed
          ? context.loc.transactionStatusPayjoinCompleted
          : payjoinStatus == PayjoinStatus.aborted
          ? context.loc.transactionStatusPayjoinAborted
          : payjoinStatus == PayjoinStatus.requested
          ? context.loc.transactionStatusPayjoinRequested
          : transaction?.isIncoming == true
          ? context.loc.transactionFilterReceive
          : context.loc.transactionFilterSend;
    final failedOrExpired =
        orderSwap?.localStatus == OrderSwapLocalStatus.failed ||
        orderSwap?.localStatus == OrderSwapLocalStatus.expired ||
        (swap != null &&
            (swap.status == SwapStatus.failed ||
                swap.status == SwapStatus.expired));

    return BBText(
      label,
      style: context.font.headlineLarge?.copyWith(
        color: failedOrExpired
            ? (orderSwap?.localStatus == OrderSwapLocalStatus.failed ||
                      swap?.status == SwapStatus.failed
                  ? context.appColors.error
                  : context.appColors.error.withValues(alpha: 0.7))
            : null,
      ),
    );
  }
}
