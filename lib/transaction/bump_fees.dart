import 'package:bb_mobile/_ui/bottom_sheet.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_cubit.dart';
import 'package:bb_mobile/network_fees/popup.dart';
import 'package:bb_mobile/transaction/bloc/state.dart';
import 'package:bb_mobile/transaction/bloc/transaction_cubit.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BumpFeesButton extends StatelessWidget {
  const BumpFeesButton({super.key});

  @override
  Widget build(BuildContext context) {
    final canRbf = context.select((TransactionCubit x) => x.state.tx.canRBF());
    final isReceive = context.select((TransactionCubit x) => x.state.tx.isReceived());
    if (!canRbf) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isReceive)
          BBButton.big(
            label: 'Bump Fees',
            onPressed: () async {
              await BumpFeesPopup.showPopUp(context);
            },
          ),
        const Gap(24),
      ],
    );
  }
}

class BumpFeesPopup extends StatelessWidget {
  const BumpFeesPopup({super.key});

  static Future showPopUp(BuildContext context) async {
    final tx = context.read<TransactionCubit>();
    final wallet = context.read<WalletBloc>();
    final networkFees = context.read<NetworkFeesCubit>();

    return showBBBottomSheet(
      context: context,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: wallet),
          BlocProvider.value(value: tx),
          BlocProvider.value(value: networkFees),
        ],
        child: BlocListener<TransactionCubit, TransactionState>(
          listenWhen: (previous, current) => previous.sentTx != current.sentTx,
          listener: (context, state) async {
            if (state.sentTx) {
              await Future.delayed(2.seconds);
              context
                ..pop()
                ..pop();
            }
          },
          child: const BumpFeesPopup(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // final amt = context.select((TransactionCubit x) => x.state.feeRate?.toString() ?? '');
    // final built = context.select((TransactionCubit x) => x.state.updatedTx != null);
    final sent = context.select((TransactionCubit x) => x.state.sentTx);
    final sending = context.select((TransactionCubit x) => x.state.sendingTx);
    final building = context.select((TransactionCubit x) => x.state.buildingTx);
    final loading = building || sending;

    final er = context.select((TransactionCubit x) => x.state.errSendingTx);
    final err = context.select((TransactionCubit x) => x.state.errBuildingTx);

    final errr = err.isNotEmpty ? err : er;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sent) ...[
            const BBHeader.popUpCenteredText(isLeft: true, text: 'Bump Fees'),
            const Gap(32),
            const Center(
              child: FaIcon(
                FontAwesomeIcons.circleCheck,
                size: 64,
                color: Colors.green,
              ),
            ).animate(delay: 100.ms).scale().fadeIn(),
            const Center(child: BBText.title('Fees Bumped Successfully')).animate().fadeIn(),
            const Gap(32),
            const Center(child: BBText.bodySmall('You will be redirected in 2 seconds')),
          ] else ...[
            BBHeader.popUpCenteredText(
              isLeft: true,
              text: 'Bump Fees',
              onBack: () {
                context.pop();
              },
            ),
            // const Gap(32),
            // const BBText.title('Enter Fees'),
            // const Gap(4),
            const FeesSelectionOptions(),
            // BBAmountInput(
            //   hint: 'update sats/vb',
            //   disabled: false,
            //   btcFormatting: false,
            //   isSats: true,
            //   onChanged: (e) {
            //     context.read<TransactionCubit>().updateFeeRate(e);
            //   },
            //   value: amt,
            // ),
            // const Gap(32),
            if (errr.isNotEmpty) BBText.errorSmall(errr),
            const Gap(8),
            BBButton.big(
              label: 'Bump Fees',
              // label: built ? 'Send Transaction' : 'Build Transaction',
              loading: loading,
              disabled: loading || sent,
              onPressed: () {
                // if (!built)
                final fees = context.read<NetworkFeesCubit>().state.feesForBump();
                context.read<TransactionCubit>().buildTx(fees);
                // else
                //   context.read<TransactionCubit>().sendTx();
              },
            ),
          ],
          const Gap(80),
        ],
      ),
    );
  }
}
