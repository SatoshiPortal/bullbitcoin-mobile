import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isFailedOrExpired
                ? context.colour.errorContainer.withValues(alpha: 0.15)
                : context.colour.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isFailedOrExpired
                  ? context.colour.error.withValues(alpha: 0.5)
                  : context.colour.outline.withValues(alpha: 0.3),
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
                        ? context.colour.error
                        : context.colour.secondary,
              ),
              const Gap(8),
              BBText(
                swap.status == SwapStatus.failed
                    ? 'Swap Failed'
                    : swap.status == SwapStatus.expired
                    ? 'Swap Expired'
                    : 'Swap Status',
                style: context.font.titleSmall?.copyWith(
                  color:
                      swap.status == SwapStatus.failed ||
                              swap.status == SwapStatus.expired
                          ? context.colour.error
                          : context.colour.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Gap(8),
          BBText(
            _getSwapStatusDescription(),
            style: context.font.bodySmall?.copyWith(
              color:
                  swap.status == SwapStatus.failed ||
                          swap.status == SwapStatus.expired
                      ? context.colour.error
                      : context.colour.onSurfaceVariant,
            ),
          ),
          if (_getAdditionalInfo().isNotEmpty) ...[
            const Gap(12),
            BBText(
              _getAdditionalInfo(),
              style: context.font.bodySmall?.copyWith(
                color:
                    swap.status == SwapStatus.failed ||
                            swap.status == SwapStatus.expired
                        ? context.colour.error.withValues(alpha: 0.8)
                        : context.colour.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getSwapStatusDescription() {
    if (swap is LnReceiveSwap) {
      switch (swap.status) {
        case SwapStatus.pending:
          return 'Your swap has been initiated. We are waiting for a payment to be received on the Lightning Network.';
        case SwapStatus.paid:
          return 'Payment has been received! We are now broadcasting the on-chain transaction to your wallet.';
        case SwapStatus.claimable:
          return 'The on-chain transaction has been confirmed. We are now claiming the funds to complete your swap.';
        case SwapStatus.completed:
          return 'Your swap has been completed successfully! The funds should now be available in your wallet.';
        case SwapStatus.failed:
          return 'There was an issue with your swap. Please contact support if funds have not been returned within 24 hours.';
        case SwapStatus.expired:
          return 'This swap has expired. Any funds sent will be automatically returned to the sender.';
        default:
          return 'Your swap is in progress. This process is automated and may take some time to complete.';
      }
    } else if (swap is LnSendSwap) {
      switch (swap.status) {
        case SwapStatus.pending:
          return 'Your swap has been initiated. We are broadcasting the on-chain transaction to lock your funds.';
        case SwapStatus.paid:
          return 'Your on-chain transaction has been broadcasted. After 1 confirmation, the Lightning payment will be sent.';
        case SwapStatus.completed:
          return 'The Lightning payment has been sent successfully! Your swap is now complete.';
        case SwapStatus.failed:
          return 'There was an issue with your swap. Your funds will be returned to your wallet automatically.';
        case SwapStatus.expired:
          return 'This swap has expired. Your funds will be automatically returned to your wallet.';
        default:
          return 'Your swap is in progress. This process is automated and may take some time to complete.';
      }
    } else if (swap is ChainSwap) {
      switch (swap.status) {
        case SwapStatus.pending:
          return swap.type == SwapType.bitcoinToLiquid
              ? 'Your swap has been created but not initiated yet.'
              : 'Your swap has been created but not initiated yet.';
        case SwapStatus.paid:
          return 'Your transaction has been broadcasted. We are now waiting for the counterparty transaction to be confirmed.';
        case SwapStatus.claimable:
          return 'The counterparty transaction has been confirmed. We are now claiming the funds to complete your swap.';
        case SwapStatus.refundable:
          return 'The swap will be refunded. Your funds will be returned to your wallet automatically.';
        case SwapStatus.completed:
          return 'Your swap has been completed successfully! The funds should now be available in your wallet.';
        case SwapStatus.failed:
          return 'There was an issue with your swap. Please contact support if funds have not been returned within 24 hours.';
        case SwapStatus.expired:
          return 'This swap has expired. Your funds will be automatically returned to your wallet.';
        default:
          return 'Your swap is in progress. This process is automated and may take some time to complete.';
      }
    }
    return 'Your swap is in progress. This process is automated and may take some time to complete.';
  }

  String _getAdditionalInfo() {
    if (swap.status == SwapStatus.failed || swap.status == SwapStatus.expired) {
      return 'If you have any questions or concerns, please contact support for assistance.';
    }

    if (swap is ChainSwap &&
        (swap.status == SwapStatus.pending || swap.status == SwapStatus.paid)) {
      return 'On-chain swaps may take some time to complete due to blockchain confirmation times.';
    }

    if (swap.status == SwapStatus.claimable) {
      return 'The swap will be completed automatically within a few seconds. If not, you can attempt a manual claim by clicking the "Retry Swap Claim" button.';
    }
    if (swap.status == SwapStatus.refundable) {
      return 'This swap will be refunded automatically within a few seconds. If not, you can attempt a manual refund by clicking the "Retry Swap Refund" button.';
    }

    return '';
  }
}
