import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/tx_list_item.dart';
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),

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
              Container(
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
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: BBText(
            'These swaps are currently in progress. Your funds are secure and will be available when the swap completes.',
            style: context.font.bodySmall?.copyWith(
              color: context.colour.outline,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const Gap(8),
        ...ongoingSwaps.map((tx) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [TxListItem(tx: tx), const Gap(8)],
          );
        }),

        const Gap(16),
      ],
    );
  }
}
