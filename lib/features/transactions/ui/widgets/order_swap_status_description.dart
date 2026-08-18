import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bull_ui/bull_ui.dart';

class OrderSwapStatusDescription extends StatelessWidget {
  final OrderSwapRecord orderSwap;

  const OrderSwapStatusDescription({super.key, required this.orderSwap});

  @override
  Widget build(BuildContext context) {
    final isChainSwap =
        orderSwap.inNetwork != OrderSwapNetwork.lightning &&
        orderSwap.outNetwork != OrderSwapNetwork.lightning;
    final failedOrExpired =
        orderSwap.localStatus == OrderSwapLocalStatus.failed ||
        orderSwap.localStatus == OrderSwapLocalStatus.expired;

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        BullBorderedTile(
          backgroundColor: failedOrExpired
              ? context.bull.errorContainer
              : context.bull.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Row(
                children: [
                  BullIcon(
                    failedOrExpired ? BullIcons.close : BullIcons.accountTree,
                    size: 20,
                    color: failedOrExpired
                        ? context.bull.error
                        : context.bull.secondary,
                  ),
                  const Gap(8),
                  BullText(
                    isChainSwap
                        ? context.loc.transactionSwapStatusTransferStatus
                        : context.loc.transactionSwapStatusSwapStatus,
                    style: context.bullText.titleSmall?.copyWith(
                      color: failedOrExpired
                          ? context.bull.error
                          : context.bull.secondary,
                      fontWeight: .bold,
                    ),
                  ),
                ],
              ),
              const Gap(8),
              BullText(
                _description(context, isChainSwap: isChainSwap),
                style: context.bullText.bodySmall?.copyWith(
                  color: failedOrExpired
                      ? context.bull.error
                      : context.bull.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (orderSwap.order?.requiresManualReview == true) ...[
          const Gap(16),
          OrderSwapUnderReviewCard(orderSwap: orderSwap),
        ],
        if (!orderSwap.localStatus.isTerminal) ...[
          const Gap(16),
          BullInfoCard(
            description: isChainSwap
                ? '${context.loc.transactionSwapDoNotUninstall}\n\n'
                      '${context.loc.transactionSwapOpenWithin24h}'
                : context.loc.transactionSwapDoNotUninstall,
            tagColor: context.bull.tertiary,
            bgColor: context.bull.warningContainer,
            boldDescription: true,
          ),
        ],
      ],
    );
  }

  String _description(BuildContext context, {required bool isChainSwap}) {
    // For a non-chain (Lightning-involved) swap, the copy must reflect
    //  whether the user is receiving or sending, since the two flows
    //  describe different on-chain/Lightning legs at each step.
    final isReceive = orderSwap.purpose == OrderSwapPurpose.receiveLightning;
    return switch (orderSwap.localStatus) {
      OrderSwapLocalStatus.completed =>
        isChainSwap
            ? context.loc.transactionSwapDescChainCompleted
            : isReceive
            ? context.loc.transactionSwapDescLnReceiveCompleted
            : context.loc.transactionSwapDescLnSendCompleted,
      OrderSwapLocalStatus.refunded =>
        // No receive-specific refunded copy exists yet; fall back to the
        //  send copy for any non-chain purpose until one is added.
        isChainSwap
            ? context.loc.coreSwapsChainCompletedRefunded
            : context.loc.coreSwapsLnSendCompletedRefunded,
      OrderSwapLocalStatus.failed =>
        isChainSwap
            ? context.loc.transactionSwapDescChainFailed
            : isReceive
            ? context.loc.transactionSwapDescLnReceiveFailed
            : context.loc.transactionSwapDescLnSendFailed,
      OrderSwapLocalStatus.expired =>
        isChainSwap
            ? context.loc.transactionSwapDescChainExpired
            : isReceive
            ? context.loc.transactionSwapDescLnReceiveExpired
            : context.loc.transactionSwapDescLnSendExpired,
      OrderSwapLocalStatus.payinBroadcast ||
      OrderSwapLocalStatus.payoutInProgress =>
        isChainSwap
            ? context.loc.transactionSwapDescChainPaid
            : isReceive
            ? context.loc.transactionSwapDescLnReceivePaid
            : context.loc.transactionSwapDescLnSendPaid,
      _ =>
        isChainSwap
            ? context.loc.transactionSwapDescChainPending
            : isReceive
            ? context.loc.transactionSwapDescLnReceivePending
            : context.loc.transactionSwapDescLnSendPending,
    };
  }
}
