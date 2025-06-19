import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/tx_list_item.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class OngoingSwapsWidget extends StatelessWidget {
  const OngoingSwapsWidget({super.key, required this.ongoingSwaps});

  final List<Transaction> ongoingSwaps;

  @override
  Widget build(BuildContext context) {
    // Early return for empty state
    if (ongoingSwaps.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        _buildDescription(context),
        const Gap(8),
        ..._buildSwapItems(),
        const Gap(16),
        const Divider(),
        const Gap(16),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: context.colour.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(Icons.swap_horiz, color: context.colour.secondary),
          const Gap(8),
          BBText(
            'Ongoing Swaps',
            style: context.font.titleMedium?.copyWith(
              color: context.colour.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _buildSwapCountBadge(context),
        ],
      ),
    );
  }

  Widget _buildSwapCountBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.colour.secondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: BBText(
        ongoingSwaps.length.toString(),
        style: context.font.labelSmall?.copyWith(
          color: context.colour.onSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDescription(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: BBText(
        'These swaps are currently in progress. Your funds are secure and will be available when the swap completes.',
        style: context.font.bodySmall?.copyWith(
          color: context.colour.outline,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Iterable<Widget> _buildSwapItems() {
    return ongoingSwaps.map((tx) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_OngoingSwapListItem(tx: tx), const Gap(8)],
      );
    });
  }
}

class _OngoingSwapListItem extends StatelessWidget {
  const _OngoingSwapListItem({required this.tx});

  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final swap = tx.swap;

    return Stack(
      children: [
        TxListItem(tx: tx),
        // Always show status badges for ongoing swaps to improve visibility
        if (swap != null) _buildStatusBadge(context, swap),
        if (swap != null) _buildProgressDescription(context, swap),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context, Swap swap) {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(2),
            bottomLeft: Radius.circular(6),
          ),
        ).copyWith(color: _getStatusColor(context, swap.status)),
        child: BBText(
          _getStatusText(swap),
          style: context.font.labelSmall?.copyWith(
            color: context.colour.onSecondary,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDescription(BuildContext context, Swap swap) {
    return Positioned(
      bottom: 12,
      left: 70,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.colour.surfaceContainerHighest.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: context.colour.outline.withValues(alpha: 0.3),
          ),
        ),
        child: BBText(
          _getSwapProgressDescription(swap),
          style: context.font.labelSmall?.copyWith(
            color: context.colour.onSurfaceVariant,
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Color _getStatusColor(BuildContext context, SwapStatus status) {
    return switch (status) {
      SwapStatus.paid ||
      SwapStatus.claimable ||
      SwapStatus.refundable ||
      SwapStatus.canCoop => context.colour.tertiary,
      SwapStatus.completed => context.colour.primary,
      SwapStatus.expired || SwapStatus.failed => context.colour.error,
      SwapStatus.pending => context.colour.secondary,
    };
  }

  String _getStatusText(Swap swap) {
    return switch (swap.status) {
      SwapStatus.paid => 'Payment Received',
      SwapStatus.claimable => 'Claimable',
      SwapStatus.refundable => 'Refundable',
      SwapStatus.canCoop => 'Cooperative Close',
      SwapStatus.completed => 'Completing',
      SwapStatus.expired => 'Expired',
      SwapStatus.failed => 'Failed',
      SwapStatus.pending => 'Pending',
    };
  }

  /// Returns detailed description of current swap progress stage
  String _getSwapProgressDescription(Swap swap) {
    return switch (swap) {
      LnReceiveSwap() => switch (swap.status) {
        SwapStatus.pending =>
          'Waiting for payment to be received on the Lightning Network',
        SwapStatus.paid =>
          'Payment received, broadcasting on-chain transaction',
        SwapStatus.claimable =>
          'On-chain transaction confirmed, claiming funds',
        SwapStatus.completed => 'Swap completed successfully',
        SwapStatus.failed => 'Swap failed - please contact support',
        SwapStatus.expired =>
          'Swap expired - funds will be returned automatically',
        SwapStatus.refundable || SwapStatus.canCoop => 'Swap in progress',
      },
      LnSendSwap() => switch (swap.status) {
        SwapStatus.pending =>
          'Broadcasting on-chain transaction to initiate swap',
        SwapStatus.paid =>
          'On-chain transaction confirmed, preparing Lightning payment',
        SwapStatus.completed => 'Lightning payment sent, swap completed',
        SwapStatus.failed =>
          'Swap failed - funds will be returned to your wallet',
        SwapStatus.expired =>
          'Swap expired - funds will be returned automatically',
        SwapStatus.claimable ||
        SwapStatus.refundable ||
        SwapStatus.canCoop => 'Swap in progress',
      },
      ChainSwap() => switch (swap.status) {
        SwapStatus.pending =>
          swap.type == SwapType.bitcoinToLiquid
              ? 'Broadcasting Bitcoin transaction to initiate swap'
              : 'Broadcasting Liquid transaction to initiate swap',
        SwapStatus.paid =>
          'Transaction confirmed, waiting for counterparty transaction',
        SwapStatus.claimable =>
          'Counterparty transaction detected, claiming funds',
        SwapStatus.completed => 'Swap completed successfully',
        SwapStatus.failed => 'Swap failed - please contact support',
        SwapStatus.expired =>
          'Swap expired - funds will be returned automatically',
        SwapStatus.refundable =>
          'Swap can be refunded - funds will be returned to your wallet',
        SwapStatus.canCoop => 'Swap in progress',
      },
    };
  }
}
