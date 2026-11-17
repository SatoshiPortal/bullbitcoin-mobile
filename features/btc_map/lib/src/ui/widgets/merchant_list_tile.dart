import 'package:btc_map/src/map_types.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'package:btc_map/src/presentation/map_localizations_x.dart';
import 'package:btc_map/src/ui/merchant_display_x.dart';

/// One place in the list: what kind it is, its name and address, and whether
/// it was verified recently.
class MerchantListTile extends StatelessWidget {
  const MerchantListTile({
    super.key,
    required this.merchant,
    required this.now,
    required this.onTap,
  });

  final Merchant merchant;

  /// When verification is judged, shared by every row of one build.
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final textTheme = Theme.of(context).textTheme;
    final address = merchant.address;
    final verification = merchant.verificationAt(now);
    final verificationColor = verification.color(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(context.bullShapes.card),
              ),
              child: BullIcon(
                merchant.category.icon,
                size: 22,
                color: colors.text,
              ),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BullText(
                    merchant.name ?? context.btcMapLoc.merchantMapUnnamed,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    color: colors.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (address != null)
                    BullText(
                      address,
                      style: textTheme.bodySmall,
                      color: colors.textMuted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const Gap(4),
                  BullBadge(
                    label: verification.shortLabel(context),
                    icon: verification.icon,
                    background: verificationColor.withValues(alpha: 0.12),
                    foreground: verificationColor,
                  ),
                ],
              ),
            ),
            BullIcon(BullIcons.chevronRight, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
