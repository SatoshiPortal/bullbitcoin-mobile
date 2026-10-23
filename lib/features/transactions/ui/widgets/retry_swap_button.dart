import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/transaction_failure_l10n.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullSnackBar, Gap;

/// Manual "retry now" for a swap stranded because the watcher could not reach
/// Boltz: drives the claim/refund directly on the script path (no Boltz API,
/// no cooperative close). The parent gates visibility on [Swap.requiresAction].
class RetrySwapButton extends StatelessWidget {
  final Swap swap;

  const RetrySwapButton({required this.swap, super.key});

  @override
  Widget build(BuildContext context) {
    final retryingSwap = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.retryingSwap,
    );
    final retryFailure = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.swapRetryFailure,
    );

    return Column(
      children: [
        BullButton.big(
          label: context.loc.transactionDetailRetryClaimRefund,
          disabled: retryingSwap,
          onPressed: () {
            log.info('Manual script-path retry for swap ${swap.id}');
            final started = context.read<TransactionDetailsCubit>().retrySwap();
            if (started) {
              BullSnackBar.show(
                context,
                message: context.loc.transactionDetailSwapRetryStarted,
              );
            }
          },
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
        if (retryFailure != null) ...[
          const Gap(16),
          Text(
            retryFailure.toTranslated(context),
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
