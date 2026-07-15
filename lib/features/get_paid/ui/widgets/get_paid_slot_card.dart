import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart'
    show BoxDecoration, BoxShape, Container, Icons;

/// A single Get Paid product row. Domain-agnostic feature composite (the
/// `UtxoTile` precedent): it lives in the feature but is built entirely out of
/// `bull_ui` primitives — a tappable [BullBorderedTile] carrying a [BullIcon],
/// title/subtitle in bull text styles, an optional [BullBadge] status chip and
/// a trailing chevron. No new `bull_ui` component is introduced.
class GetPaidSlotCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  /// Status chip text — null renders no chip (the "unset" look).
  final String? statusLabel;

  /// Success tint when true (Active), muted tint otherwise (Not published).
  final bool statusActive;
  final VoidCallback onTap;

  const GetPaidSlotCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.statusLabel,
    this.statusActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return BullBorderedTile(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BullIcon(icon, size: 28, color: colors.primary),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Green "active" dot — same recipe as the electrum server
                    // list item's online indicator. Rendered only when active.
                    if (statusActive) ...[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.success,
                        ),
                      ),
                      const Gap(8),
                    ],
                    Flexible(
                      child: Text(
                        title,
                        style: context.bullText.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(4),
                Text(
                  subtitle,
                  style: context.bullText.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (statusLabel != null) ...[
                  const Gap(10),
                  _StatusBadge(label: statusLabel!, active: statusActive),
                ],
              ],
            ),
          ),
          const Gap(12),
          BullIcon(Icons.chevron_right, size: 24, color: colors.textMuted),
        ],
      ),
    );
  }
}

/// The status pill — same alpha-tinted semantic recipe as the coins keychain /
/// frozen badges: success for Active, muted for "Not published".
class _StatusBadge extends StatelessWidget {
  final String label;
  final bool active;

  const _StatusBadge({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final accent = active ? colors.success : colors.textMuted;
    return BullBadge(
      label: label,
      uppercase: true,
      radius: BullRadius.xxs,
      background: accent.withValues(alpha: active ? 0.14 : 0.16),
      foreground: accent,
    );
  }
}
