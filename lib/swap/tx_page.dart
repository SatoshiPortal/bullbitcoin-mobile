import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/receive/receive_page.dart';
import 'package:bb_mobile/swap/bloc/swap_bloc.dart';
import 'package:bb_mobile/transaction/bloc/transaction_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';

class SwapTxPage extends StatelessWidget {
  const SwapTxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tx = context.select((TransactionCubit cubit) => cubit.state.tx);

    final swap = tx.swapTx;
    if (swap == null) return const SizedBox.shrink();

    final amt = swap.outAmount;
    final amount = context.select((CurrencyCubit x) => x.state.getAmountInUnits(amt));
    final isReceive = !swap.isSubmarine;

    final date = tx.getDateTimeStr();
    final id = swap.id;
    const fees = '';
    final invoice = swap.invoice;
    final units = context.select(
      (CurrencyCubit cubit) => cubit.state.getUnitString(),
    );

    final status = context.select((SwapBloc _) => _.state.showStatus(swap))?.toString() ?? '';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Gap(24),
              BBText.title(
                isReceive ? 'Amount received' : 'Amount sent',
              ),
              const Gap(4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Container(
                    transformAlignment: Alignment.center,
                    transform: Matrix4.identity()..rotateZ(isReceive ? 1 : -1),
                    child: const FaIcon(
                      FontAwesomeIcons.arrowRight,
                      size: 12,
                    ),
                  ),
                  const Gap(8),
                  BBText.titleLarge(
                    amount,
                    isBold: true,
                  ),
                  const Gap(4),
                  BBText.title(
                    units,
                    isBold: true,
                  ),
                ],
              ),
              const Gap(24),
              if (id.isNotEmpty) ...[
                const BBText.title('Transaction ID'),
                const Gap(4),
                BBText.titleLarge(
                  id,
                  isBold: true,
                ),
                const Gap(24),
              ],
              const Gap(4),
              const BBText.title('Status'),
              const Gap(4),
              BBText.titleLarge(
                status,
                isBold: true,
              ),
              const Gap(4),
              const Gap(24),
              BBText.title(
                isReceive ? 'Tranaction received' : 'Transaction sent',
              ),
              const Gap(4),
              BBText.titleLarge(date, isBold: true),
              const Gap(32),
              Center(
                child: SizedBox(
                  width: 300,
                  child: Column(
                    children: [
                      ReceiveQRDisplay(address: invoice),
                      ReceiveDisplayAddress(
                        addressQr: invoice,
                        fontSize: 10,
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(100),
            ],
          ),
        ),
      ),
    );
  }
}
