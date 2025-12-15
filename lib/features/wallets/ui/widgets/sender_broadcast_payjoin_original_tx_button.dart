import 'package:bb_mobile/core_deprecated/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/logger.dart';
import 'package:bb_mobile/core_deprecated/widgets/buttons/button.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SenderBroadcastPayjoinOriginalTxButton extends StatelessWidget {
  const SenderBroadcastPayjoinOriginalTxButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isBroadcastingPayjoinOriginalTx = context.select(
      (TransactionDetailsCubit bloc) =>
          bloc.state.isBroadcastingPayjoinOriginalTx,
    );
    final broadcastOriginalTransactionException = context.select(
      (TransactionDetailsCubit bloc) =>
          bloc.state.err is BroadcastOriginalTransactionException
          ? bloc.state.err! as BroadcastOriginalTransactionException
          : null,
    );
    return Column(
      children: [
        Text(
          "Not receiving a payjoin proposal from the receiver?",
          style: context.font.titleSmall,
          textAlign: TextAlign.center,
          maxLines: 2,
        ),
        const Gap(16),
        BBButton.big(
          label: 'Send without payjoin',
          disabled: isBroadcastingPayjoinOriginalTx,
          onPressed: () {
            log.info('Send without payjoin');
            context
                .read<TransactionDetailsCubit>()
                .broadcastPayjoinOriginalTx();
          },
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
        const Gap(16),
        if (broadcastOriginalTransactionException != null) ...[
          Text(
            'Error: ${broadcastOriginalTransactionException.message}',
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.error,
            ),
            textAlign: TextAlign.center,
          ),
          const Gap(16),
        ],
      ],
    );
  }
}
