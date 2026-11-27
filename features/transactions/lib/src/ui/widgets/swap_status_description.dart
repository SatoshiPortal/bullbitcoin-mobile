import 'package:swaps/swaps.dart';
import 'package:bull_ui/bull_ui.dart' show BullThemeX;
import 'package:transactions/src/presentation/transactions_localizations_x.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullShapesX, BullText, Gap, BullTypographyX;

class SwapStatusDescription extends StatelessWidget {
  const SwapStatusDescription({required this.swap});

  final Swap swap;

  @override
  Widget build(BuildContext context) {
    final bool isFailedOrExpired =
        swap.status == SwapStatus.failed || swap.status == SwapStatus.expired;

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isFailedOrExpired
                ? context.bull.errorContainer.withValues(alpha: 0.15)
                : context.bull.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(context.bullShapes.card),
            border: Border.all(
              color: isFailedOrExpired
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
                    swap.status == SwapStatus.failed ||
                            swap.status == SwapStatus.expired
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline,
                    size: 20,
                    color:
                        swap.status == SwapStatus.failed ||
                            swap.status == SwapStatus.expired
                        ? context.bull.error
                        : context.bull.secondary,
                  ),
                  const Gap(8),
                  BullText(
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
                    style: context.bullType.label.copyWith(
                      color:
                          swap.status == SwapStatus.failed ||
                              swap.status == SwapStatus.expired
                          ? context.bull.error
                          : context.bull.secondary,
                      fontWeight: .bold,
                    ),
                  ),
                ],
              ),
              const Gap(8),
              BullText(
                _getSwapStatusDescription(context),
                style: context.bullType.label
                    .copyWith(fontWeight: FontWeight.w400)
                    .copyWith(
                      color:
                          swap.status == SwapStatus.failed ||
                              swap.status == SwapStatus.expired
                          ? context.bull.error
                          : context.bull.onSurfaceVariant,
                    ),
              ),
              if (_getAdditionalInfo(context).isNotEmpty) ...[
                const Gap(12),
                BullText(
                  _getAdditionalInfo(context),
                  style: context.bullType.label
                      .copyWith(fontWeight: FontWeight.w400)
                      .copyWith(
                        color:
                            swap.status == SwapStatus.failed ||
                                swap.status == SwapStatus.expired
                            ? context.bull.error.withValues(alpha: 0.8)
                            : context.bull.outline,
                        fontStyle: .italic,
                      ),
                ),
              ],
            ],
          ),
        ),
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
        case SwapStatus.refunded:
          return context.loc.coreSwapsLnSendCompletedRefunded;
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
        case SwapStatus.refunded:
          return context.loc.coreSwapsChainCompletedRefunded;
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
