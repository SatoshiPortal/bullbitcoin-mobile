import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SwapTxHomeListItem extends StatelessWidget {
  const SwapTxHomeListItem({super.key, required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final swap = transaction.swapTx;
    if (swap == null) return const SizedBox.shrink();

    final amt = swap.outAmount;
    final amount = context.select((CurrencyCubit x) => x.state.getAmountInUnits(amt));
    final isReceive = !swap.isSubmarine;

    // final invoice = swap.invoice;
    final date = transaction.getDateTimeStr();

    return InkWell(
      onTap: () {
        context.push('/tx', extra: transaction);
      },
      child: Padding(
        padding: const EdgeInsets.only(
          top: 8,
          bottom: 16,
          left: 24,
          right: 24,
        ),
        child: Row(
          children: [
            Container(
              transformAlignment: Alignment.center,
              transform: Matrix4.identity()..rotateZ(isReceive ? 1.6 : -1.6),
              child: const FaIcon(FontAwesomeIcons.arrowRight),
            ),
            const Gap(8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText.titleLarge(amount),
                // if (label.isNotEmpty) ...[
                //   const Gap(4),
                //   BBText.bodySmall(label),
                // ],
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BBText.bodySmall(
                  date,
                  // : timeago.format(tx.getDateTime()),
                  removeColourOpacity: true,
                ),
              ],
            ),

            // Align(
            //   alignment: Alignment.bottomRight,
            //   child: BBText.bodySmall(
            //     label,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
