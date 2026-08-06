import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: failedOrExpired
                ? context.appColors.errorContainer.withValues(alpha: 0.15)
                : context.appColors.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: failedOrExpired
                  ? context.appColors.error.withValues(alpha: 0.5)
                  : context.appColors.outline.withValues(alpha: 0.3),
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
                        ? context.appColors.error
                        : context.appColors.secondary,
                  ),
                  const Gap(8),
                  BBText(
                    isChainSwap
                        ? context.loc.transactionSwapStatusTransferStatus
                        : context.loc.transactionSwapStatusSwapStatus,
                    style: context.font.titleSmall?.copyWith(
                      color: failedOrExpired
                          ? context.appColors.error
                          : context.appColors.secondary,
                      fontWeight: .bold,
                    ),
                  ),
                ],
              ),
              const Gap(8),
              BBText(
                _description(context, isChainSwap: isChainSwap),
                style: context.font.bodySmall?.copyWith(
                  color: failedOrExpired
                      ? context.appColors.error
                      : context.appColors.onSurfaceVariant,
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
          InfoCard(
            description: isChainSwap
                ? '${context.loc.transactionSwapDoNotUninstall}\n\n'
                      '${context.loc.transactionSwapOpenWithin24h}'
                : context.loc.transactionSwapDoNotUninstall,
            tagColor: context.appColors.tertiary,
            bgColor: context.appColors.warningContainer,
            boldDescription: true,
          ),
        ],
      ],
    );
  }

  String _description(BuildContext context, {required bool isChainSwap}) {
    return switch (orderSwap.localStatus) {
      OrderSwapLocalStatus.completed =>
        isChainSwap
            ? context.loc.transactionSwapDescChainCompleted
            : context.loc.transactionSwapDescLnSendCompleted,
      OrderSwapLocalStatus.refunded =>
        isChainSwap
            ? context.loc.coreSwapsChainCompletedRefunded
            : context.loc.coreSwapsLnSendCompletedRefunded,
      OrderSwapLocalStatus.failed =>
        isChainSwap
            ? context.loc.transactionSwapDescChainFailed
            : context.loc.transactionSwapDescLnSendFailed,
      OrderSwapLocalStatus.expired =>
        isChainSwap
            ? context.loc.transactionSwapDescChainExpired
            : context.loc.transactionSwapDescLnSendExpired,
      OrderSwapLocalStatus.payinBroadcast ||
      OrderSwapLocalStatus.payoutInProgress =>
        isChainSwap
            ? context.loc.transactionSwapDescChainPaid
            : context.loc.transactionSwapDescLnSendPaid,
      _ =>
        isChainSwap
            ? context.loc.transactionSwapDescChainPending
            : context.loc.transactionSwapDescLnSendPending,
    };
  }
}
