import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/tx_list_item.dart';
import 'package:bull_ui/bull_ui.dart';

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
      crossAxisAlignment: .start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),

          child: Row(
            children: [
              BullIcon(BullIcons.sync, color: context.bull.secondary),
              const Gap(8),
              BullText(
                context.loc.transactionListOngoingTransfersTitle,
                style: context.bullText.titleMedium?.copyWith(
                  color: context.bull.secondary,
                  fontWeight: .w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.bull.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: BullText(
                  ongoingSwaps.length.toString(),
                  style: context.bullText.labelSmall?.copyWith(
                    color: context.bull.onSecondary,
                    fontWeight: .w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: BullText(
            context.loc.transactionListOngoingTransfersDescription,
            style: context.bullText.bodySmall?.copyWith(
              color: context.bull.outline,
              fontStyle: .italic,
            ),
          ),
        ),
        const Gap(8),
        ...ongoingSwaps.map((tx) {
          return Column(
            crossAxisAlignment: .start,
            children: [
              TxListItem(tx: tx),
              const Gap(8),
            ],
          );
        }),

        const Gap(16),
      ],
    );
  }
}
