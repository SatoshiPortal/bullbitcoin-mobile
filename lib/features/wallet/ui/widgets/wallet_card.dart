import 'package:bull_ui/app_theme.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAmount,
        BullAmountScope,
        BullFadingLinearProgress,
        BullQuickActionBar,
        BullShapesX,
        Gap,
        BullTypographyX;

class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.tagColor,
    required this.title,
    required this.description,
    required this.balanceSat,
    this.onTap,
    this.isSyncing = false,
  });

  final Color tagColor;
  final String title;
  final String description;
  final int balanceSat;
  final bool isSyncing;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = context.bullType.body.copyWith(
      fontWeight: FontWeight.w500,
    );
    final label = context.bullType.caption;
    final accent = context.appColors.secondary;
    final muted = context.appColors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.bullShapes.card),
        child: Material(
          elevation: 2,
          shadowColor: context.appColors.onSurface.withValues(alpha: 0.5),
          color: context.appColors.walletCardBackground,
          borderRadius: BorderRadius.circular(context.bullShapes.card),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: BullQuickActionBar.minHeight,
            ),
            decoration: BoxDecoration(
              color: context.appColors.walletCardBackground,
              border: Border(left: BorderSide(color: tagColor, width: 4)),
              borderRadius: BorderRadius.circular(context.bullShapes.card),
            ),
            child: Stack(
              // Centres the content once the minimum height exceeds it.
              alignment: AlignmentDirectional.centerStart,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: .start,
                          mainAxisAlignment: .center,
                          children: [
                            _line(context, title, bodyStyle, accent, false),
                            const Gap(4),
                            _line(context, description, label, muted, true),
                          ],
                        ),
                      ),
                      const Gap(8),
                      Icon(
                        Icons.chevron_right,
                        color: context.appColors.onSurfaceVariant,
                        size: 24,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: BullFadingLinearProgress(
                    trigger: isSyncing,
                    backgroundColor: context.appColors.transparent,
                    foregroundColor: context.appColors.secondary,
                    height: 3.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // A long label gives way to the balance, and a balance too wide for the
  // card scales down rather than overflowing it. The cap follows the screen,
  // not a LayoutBuilder: cards sit in intrinsic-height columns, which cannot
  // measure a LayoutBuilder.
  Widget _line(
    BuildContext context,
    String text,
    TextStyle? style,
    Color color,
    bool showFiat,
  ) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: style?.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const Gap(4),
      ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.5,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: showFiat
              ? FiatAmountText.quote(
                  balanceSat,
                  hideAmounts:
                      BullAmountScope.maybeOf(context)?.snapshot.hideAmounts ??
                      true,
                  style: style,
                  color: color,
                )
              : BullAmount.signedSats(
                  balanceSat,
                  interactive: false,
                  style: style,
                  color: color,
                ),
        ),
      ),
    ],
  );
}
