import 'package:bull_ui/bull_ui.dart' show BullThemeX;
import 'package:transactions/src/presentation/transactions_localizations_x.dart';
import 'package:transactions/src/ui/widgets/tx_list_item.dart';
import 'package:transactions/src/domain/entities/transaction.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullShapesX, BullText, Gap, BullTypographyX;

class OngoingSwapsWidget extends StatelessWidget {
  const OngoingSwapsWidget({
    super.key,
    required this.ongoingSwaps,
    required this.onDetailsClosed,
    this.walletScoped = false,
  });

  final List<Transaction> ongoingSwaps;
  final VoidCallback onDetailsClosed;

  /// The list shows one wallet's transactions.
  final bool walletScoped;

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
              Icon(Icons.swap_horiz, color: context.bull.secondary),
              const Gap(8),
              BullText(
                context.loc.transactionListOngoingTransfersTitle,
                style: context.bullType.body
                    .copyWith(fontWeight: FontWeight.w500)
                    .copyWith(color: context.bull.secondary, fontWeight: .w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.bull.secondary,
                  borderRadius: BorderRadius.circular(context.bullShapes.dot),
                ),
                child: BullText(
                  ongoingSwaps.length.toString(),
                  style: context.bullType.caption.copyWith(
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
            style: context.bullType.label
                .copyWith(fontWeight: FontWeight.w400)
                .copyWith(color: context.bull.outline, fontStyle: .italic),
          ),
        ),
        const Gap(8),
        ...ongoingSwaps.map((tx) {
          return Column(
            key: ValueKey((tx.swap?.id, tx.orderSwap?.localId, tx.txId)),
            crossAxisAlignment: .start,
            children: [
              TransactionListItem.transaction(
                tx,
                onDetailsClosed: onDetailsClosed,
                walletScoped: walletScoped,
              ),
              const Gap(8),
            ],
          );
        }),

        const Gap(16),
      ],
    );
  }
}
