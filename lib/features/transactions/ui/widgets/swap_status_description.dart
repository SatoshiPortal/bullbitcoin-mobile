import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class SwapStatusDescription extends StatelessWidget {
  const SwapStatusDescription({required this.swap});

  final Swap swap;

  @override
  Widget build(BuildContext context) {
    final bool isFailedOrExpired =
        swap.status == SwapStatus.failed || swap.status == SwapStatus.expired;
    final bool shouldShowWarning = swap.status != SwapStatus.completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                isFailedOrExpired
                    ? context.appColors.errorContainer.withValues(alpha: 0.15)
                    : context.appColors.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  isFailedOrExpired
                      ? context.appColors.error.withValues(alpha: 0.5)
                      : context.appColors.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    swap.status == SwapStatus.failed ||
                            swap.status == SwapStatus.expired
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline,
                    size: 20,
                    color:
                        swap.status == SwapStatus.failed ||
                                swap.status == SwapStatus.expired
                            ? context.appColors.error
                            : context.appColors.secondary,
                  ),
                  const Gap(8),
                  BBText(
                    swap.status == SwapStatus.failed
                        ? (swap.isChainSwap
                            ? context.loc.transactionStatusTransferFailed
                            : context.loc.transactionStatusSwapFailed)
                        : swap.status == SwapStatus.expired
                        ? (swap.isChainSwap
                            ? context.loc.transactionStatusTransferExpired
                            : context.loc.transactionStatusSwapExpired)
                        : (swap.isChainSwap
                            ? context.loc.transactionSwapStatusTransferStatus
                            : context.loc.transactionSwapStatusSwapStatus),
                    style: context.font.titleSmall?.copyWith(
                      color:
                          swap.status == SwapStatus.failed ||
                                  swap.status == SwapStatus.expired
                              ? context.appColors.error
                              : context.appColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Gap(8),
              BBText(
                _getSwapStatusDescription(context),
                style: context.font.bodySmall?.copyWith(
                  color:
                      swap.status == SwapStatus.failed ||
                              swap.status == SwapStatus.expired
                          ? context.appColors.error
                          : context.appColors.onSurfaceVariant,
                ),
              ),
              if (_getAdditionalInfo(context).isNotEmpty) ...[
                const Gap(12),
                BBText(
                  _getAdditionalInfo(context),
                  style: context.font.bodySmall?.copyWith(
                    color:
                        swap.status == SwapStatus.failed ||
                                swap.status == SwapStatus.expired
                            ? context.appColors.error.withValues(alpha: 0.8)
                            : context.appColors.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (shouldShowWarning) ...[
          const Gap(16),
          InfoCard(
            description: context.loc.transactionSwapDoNotUninstall,
            tagColor: context.appColors.tertiary,
            bgColor: context.appColors.surfaceFixed,
            boldDescription: true,
          ),
        ],
      ],
    );
  }

  String _getSwapStatusDescription(BuildContext context) {
    if (swap is LnReceiveSwap) {
      switch (swap.status) {
        case SwapStatus.pending:
          return context.loc.transactionSwapDescLnReceivePending;
        case SwapStatus.paid:
          return context.loc.transactionSwapDescLnReceivePaid;
        case SwapStatus.claimable:
          return context.loc.transactionSwapDescLnReceiveClaimable;
        case SwapStatus.completed:
          return context.loc.transactionSwapDescLnReceiveCompleted;
        case SwapStatus.failed:
          return context.loc.transactionSwapDescLnReceiveFailed;
        case SwapStatus.expired:
          return context.loc.transactionSwapDescLnReceiveExpired;
        default:
          return context.loc.transactionSwapDescLnReceiveDefault;
      }
    } else if (swap is LnSendSwap) {
      switch (swap.status) {
        case SwapStatus.pending:
          return context.loc.transactionSwapDescLnSendPending;
        case SwapStatus.paid:
          return context.loc.transactionSwapDescLnSendPaid;
        case SwapStatus.completed:
          return context.loc.transactionSwapDescLnSendCompleted;
        case SwapStatus.failed:
          return context.loc.transactionSwapDescLnSendFailed;
        case SwapStatus.expired:
          return context.loc.transactionSwapDescLnSendExpired;
        default:
          return context.loc.transactionSwapDescLnSendDefault;
      }
    } else if (swap is ChainSwap) {
      switch (swap.status) {
        case SwapStatus.pending:
          return context.loc.transactionSwapDescChainPending;
        case SwapStatus.paid:
          return context.loc.transactionSwapDescChainPaid;
        case SwapStatus.claimable:
          return context.loc.transactionSwapDescChainClaimable;
        case SwapStatus.refundable:
          return context.loc.transactionSwapDescChainRefundable;
        case SwapStatus.completed:
          return context.loc.transactionSwapDescChainCompleted;
        case SwapStatus.failed:
          return context.loc.transactionSwapDescChainFailed;
        case SwapStatus.expired:
          return context.loc.transactionSwapDescChainExpired;
        default:
          return context.loc.transactionSwapDescChainDefault;
      }
    }
    return context.loc.transactionSwapDescChainDefault;
  }

  String _getAdditionalInfo(BuildContext context) {
    if (swap.status == SwapStatus.failed || swap.status == SwapStatus.expired) {
      return context.loc.transactionSwapInfoFailedExpired;
    }

    if (swap is ChainSwap &&
        (swap.status == SwapStatus.pending || swap.status == SwapStatus.paid)) {
      return context.loc.transactionSwapInfoChainDelay;
    }

    if (swap.status == SwapStatus.claimable) {
      return swap.isChainSwap
          ? context.loc.transactionSwapInfoClaimableTransfer
          : context.loc.transactionSwapInfoClaimableSwap;
    }
    if (swap.status == SwapStatus.refundable) {
      return swap.isChainSwap
          ? context.loc.transactionSwapInfoRefundableTransfer
          : context.loc.transactionSwapInfoRefundableSwap;
    }

    return '';
  }
}
