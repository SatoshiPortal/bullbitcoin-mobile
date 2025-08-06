import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
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
    return Column(
      children: [
        BBText(
          "Not receiving a payjoin proposal from the receiver?",
          style: context.font.titleSmall,
          textAlign: TextAlign.center,
          maxLines: 2,
        ),
        const Gap(16),
        BBButton.big(
          label: 'Send without payjoin',
          iconData:
              isBroadcastingPayjoinOriginalTx
                  ? Icons.hourglass_top
                  : Icons.send,
          disabled: isBroadcastingPayjoinOriginalTx,
          onPressed: () {
            log.info('Send without payjoin');
            context
                .read<TransactionDetailsCubit>()
                .broadcastPayjoinOriginalTx();
          },
          bgColor: context.colour.secondary,
          textColor: context.colour.onSecondary,
        ),
      ],
    );
  }
}
