import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';

/// A generic small pill: background + foreground + optional leading icon +
/// text. **New.** Backs the keychain badge, Frozen marker, conf pill, and count
/// badge. Caller supplies the colours (from `context.bull`).
class BullBadge extends StatelessWidget {
  const BullBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.iconSize = 11,
    this.uppercase = false,
    this.radius = BullRadius.xxs,
    this.border,
  });

  /// Badge text.
  final String label;

  /// Fill colour.
  final Color background;

  /// Text and icon colour.
  final Color foreground;

  /// Optional leading icon glyph.
  final IconData? icon;

  /// Icon size.
  final double iconSize;

  /// When true, the label is upper-cased (keychain badge style).
  final bool uppercase;

  /// Corner radius.
  final double radius;

  /// Optional outline. When null the pill has no border (the default).
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            BullIcon(icon!, size: iconSize, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            uppercase ? label.toUpperCase() : label,
            style:
                (uppercase
                        ? Theme.of(context).textTheme.labelSmall
                        : Theme.of(context).textTheme.labelLarge)
                    ?.copyWith(
                      fontSize: uppercase ? 10.5 : 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: uppercase ? 0.2 : null,
                      color: foreground,
                    ),
          ),
        ],
      ),
    );
  }
}

/// Alias of [BullBadge] — same generic pill, named for call-site clarity where
/// the element reads more like a pill than a badge.
typedef BullPill = BullBadge;
