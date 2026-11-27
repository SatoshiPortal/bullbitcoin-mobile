import 'package:material_ui/material_ui.dart';

import '../layout/gap.dart';
import '../theme/bull_shapes.dart';
import '../theme/bull_theme.dart';
import '../theme/bull_tokens.dart';
import '../theme/bull_typography.dart';

/// A tappable notice on the home screen about something in progress: an
/// icon, the headline (an amount, typically), a short status line and an
/// optional detail under it.
class BullHomeNotice extends StatelessWidget {
  const BullHomeNotice({
    super.key,
    required this.icon,
    required this.headline,
    required this.status,
    this.detail,
    this.onTap,
  });

  final IconData icon;
  final Widget headline;
  final String status;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final radius = BorderRadius.circular(context.bullShapes.card);
    return Semantics(
      button: onTap != null,
      child: Material(
        elevation: 2,
        shadowColor: colors.onSurface.withValues(alpha: 0.5),
        color: colors.background,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: BullSizes.homeCard),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(
                      context.bullShapes.card,
                    ),
                  ),
                  child: Icon(icon, color: colors.onSurface, size: 20),
                ),
                const Gap(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DefaultTextStyle.merge(
                        style: context.bullType.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                        child: headline,
                      ),
                      const Gap(4),
                      Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.bullType.label.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                      if (detail case final detail?)
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.bullType.caption.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                const Gap(8),
                Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
