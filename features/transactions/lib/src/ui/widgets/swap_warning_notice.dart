import 'package:bull_ui/bull_ui.dart' show BullThemeX;
import 'package:transactions/src/presentation/transactions_localizations_x.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullShapesX, BullText, Gap, BullTypographyX;

/// What the user must not do while a swap is in progress. A chain swap also
/// needs the app opened within a day to complete.
class SwapWarningNotice extends StatelessWidget {
  const SwapWarningNotice({super.key, required this.isChainSwap});

  final bool isChainSwap;

  @override
  Widget build(BuildContext context) {
    final style = context.bullType.label.copyWith(
      fontWeight: FontWeight.w600,
      color: context.bull.onSurface,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.bull.warningContainer,
        borderRadius: BorderRadius.circular(context.bullShapes.card),
      ),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Icon(Icons.info_outline, color: context.bull.tertiary),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                BullText(
                  context.loc.transactionSwapDoNotUninstall,
                  style: style,
                ),
                if (isChainSwap) ...[
                  const Gap(8),
                  BullText(
                    context.loc.transactionSwapOpenWithin24h,
                    style: style,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
