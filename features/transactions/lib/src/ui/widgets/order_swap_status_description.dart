import 'package:bull_ui/bull_ui.dart' show BullThemeX;
import 'package:transactions/src/presentation/transactions_localizations_x.dart';
import 'package:swaps/order_swaps.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullShapesX, BullText, Gap, BullTypographyX;

class OrderSwapStatusDescription extends StatelessWidget {
  final OrderSwapRecord orderSwap;
  final Widget Function(OrderSwapRecord) orderSwapUnderReview;

  const OrderSwapStatusDescription({
    super.key,
    required this.orderSwap,
    required this.orderSwapUnderReview,
  });

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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: failedOrExpired
                ? context.bull.errorContainer.withValues(alpha: 0.15)
                : context.bull.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(context.bullShapes.card),
            border: Border.all(
              color: failedOrExpired
                  ? context.bull.error.withValues(alpha: 0.5)
                  : context.bull.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Row(
                children: [
                  Icon(
                    failedOrExpired
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline,
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
                    style: context.bullType.label.copyWith(
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
                style: context.bullType.label
                    .copyWith(fontWeight: FontWeight.w400)
                    .copyWith(
                      color: failedOrExpired
                          ? context.bull.error
                          : context.bull.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        if (orderSwap.order?.requiresManualReview == true) ...[
          const Gap(16),
          orderSwapUnderReview(orderSwap),
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
