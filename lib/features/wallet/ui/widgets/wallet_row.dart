import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/currency_text.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullFadingLinearProgress, BullShapesX, BullSpacing, Gap;
import 'package:material_ui/material_ui.dart';

class WalletRow extends StatelessWidget {
  const WalletRow({
    super.key,
    required this.tagColor,
    required this.title,
    required this.description,
    required this.balanceSat,
    this.onTap,
    this.isSyncing = false,
    this.fiatCurrency,
  });

  final Color tagColor;
  final String title;
  final String description;
  final int? balanceSat;
  final bool isSyncing;
  final VoidCallback? onTap;
  final String? fiatCurrency;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final balanceSat = this.balanceSat;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.bullShapes.card),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BullSpacing.xs,
              vertical: BullSpacing.sm,
            ),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: tagColor,
                    borderRadius: BorderRadius.circular(
                      context.bullShapes.badge,
                    ),
                  ),
                  child: const SizedBox(width: 4, height: 36),
                ),
                const Gap(BullSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: context.font.bodyLarge?.copyWith(
                          color: colors.text,
                          fontWeight: .w600,
                        ),
                      ),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: context.font.labelMedium?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(BullSpacing.md),
                if (balanceSat != null)
                  Column(
                    crossAxisAlignment: .end,
                    children: [
                      CurrencyText(
                        balanceSat,
                        showFiat: false,
                        style: context.font.bodyLarge?.copyWith(
                          fontWeight: .w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        color: colors.text,
                      ),
                      CurrencyText(
                        balanceSat,
                        showFiat: true,
                        fiatCurrency: fiatCurrency,
                        style: context.font.labelMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        color: colors.textMuted,
                      ),
                    ],
                  ),
                const Gap(BullSpacing.xs),
                Icon(Icons.chevron_right, size: 20, color: colors.textMuted),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BullFadingLinearProgress(
              trigger: isSyncing,
              backgroundColor: colors.transparent,
              foregroundColor: colors.secondary,
              height: 2,
            ),
          ),
        ],
      ),
    );
  }
}
