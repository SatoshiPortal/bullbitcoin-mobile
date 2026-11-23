import 'package:swaps/swaps.dart';
import 'package:bull_ui/bull_ui.dart' show BullThemeX;
import 'package:transactions/src/presentation/transactions_localizations_x.dart';
import 'package:transactions/src/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:transactions/src/presentation/transaction_failure_l10n.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullSnackBar, Gap, BullTypographyX;

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
        BullButton.secondary(
          label: context.loc.transactionDetailRetryClaimRefund,
          onPressed: (retryingSwap)
              ? null
              : () {
                  log.info('Manual script-path retry for swap ${swap.id}');
                  final started = context
                      .read<TransactionDetailsCubit>()
                      .retrySwap();
                  if (started) {
                    BullSnackBar.show(
                      context,
                      message: context.loc.transactionDetailSwapRetryStarted,
                    );
                  }
                },
        ),
        if (retryFailure != null) ...[
          const Gap(16),
          Text(
            retryFailure.toTranslated(context),
            style: context.bullType.body.copyWith(color: context.bull.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
