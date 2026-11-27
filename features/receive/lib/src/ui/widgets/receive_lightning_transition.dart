import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:receive/src/presentation/bloc/receive_bloc.dart';
import 'package:transactions/payment_status.dart';
import 'package:receive/src/ui/receive_localizations.dart';
import 'package:receive/src/ui/screens/receive_payment_received_screen.dart';
import 'package:swaps/swaps.dart' show SwapStatus;
import 'package:transactions/routes.dart' show TransactionDetailsView;

class ReceiveLightningTransition extends StatelessWidget {
  const ReceiveLightningTransition({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final swap = context.select((ReceiveBloc bloc) => bloc.state.lightningSwap);
    if (swap == null) return const SizedBox.shrink();
    final direct = swap.wasDirectPayment;
    final steps = [
      direct
          ? context.loc.receiveStepPaymentDetected
          : context.loc.receiveStepBoltzLockup,
      if (!direct) context.loc.receiveStepClaimBroadcast,
      direct
          ? context.loc.receiveStepConfirmed
          : context.loc.receiveStepComplete,
    ];
    final hasReceiveTxid = swap.receiveTxid?.isNotEmpty ?? false;
    final confirmed = context.select(
      (ReceiveBloc bloc) => bloc.state.settlementConfirmed,
    );
    final progress = receiveLightningProgress(
      steps: steps,
      status: swap.status,
      wasDirectPayment: direct,
      hasReceiveTxid: hasReceiveTxid,
      confirmed: confirmed,
    );
    return BullPaymentTransition(
      network: BullPaymentNetwork.lightning,
      direction: BullPaymentDirection.incoming,
      phase: receiveLightningPhase(
        status: swap.status,
        wasDirectPayment: direct,
        hasReceiveTxid: hasReceiveTxid,
        confirmed: confirmed,
      ),
      progress: progress,
      status: steps[progress.completed],
      statusTag: direct
          ? steps[progress.completed]
          : switch (swap.status) {
              SwapStatus.pending => context.loc.receiveStepPending,
              SwapStatus.paid => context.loc.receiveStatusPaid,
              SwapStatus.claimable => context.loc.receiveStatusClaimable,
              SwapStatus.completed => steps[progress.completed],
              SwapStatus.expired => context.loc.receiveStatusExpired,
              SwapStatus.failed => context.loc.receiveStepFailed,
              SwapStatus.refundable => context.loc.receiveStatusRefundable,
              SwapStatus.refunded => context.loc.receiveStatusRefunded,
              SwapStatus.canCoop => context.loc.receiveStatusCooperative,
            },
      skipLabel: context.loc.receiveViewDetails,
      onSkip: () =>
          openReceiveDetails(context, view: TransactionDetailsView.details),
      onBack: onBack,
      onDone: () {},
    );
  }
}
