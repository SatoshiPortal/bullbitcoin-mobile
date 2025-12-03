import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
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
    final order = transaction?.order;
    final isOrder = transaction?.isOrder;

    return BBText(
      (swap != null && swap.swapCompleted && swap.isChainSwap)
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
          : transaction?.isOngoingPayjoinSender == true
          ? context.loc.transactionStatusPayjoinRequested
          : transaction?.isIncoming == true
          ? context.loc.transactionFilterReceive
          : context.loc.transactionFilterSend,
      style: context.font.headlineLarge?.copyWith(
        color:
            swap != null &&
                    (swap.status == SwapStatus.failed ||
                        swap.status == SwapStatus.expired)
                ? swap.status == SwapStatus.failed
                    ? context.appColors.error
                    : context.appColors.error.withValues(alpha: 0.7)
                : null,
      ),
    );
  }
}
