import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
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
          ? 'Swap Completed'
          : (swap != null && swap.swapInProgress && swap.isChainSwap)
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
          : isOrder == true
          ? order!.orderType.value
          : transaction?.isOngoingPayjoinSender == true
          ? 'Payjoin requested'
          : transaction?.isIncoming == true
          ? 'Receive'
          : 'Send',
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
    );
  }
}
