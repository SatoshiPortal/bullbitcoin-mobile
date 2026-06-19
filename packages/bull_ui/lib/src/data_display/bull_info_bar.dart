import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';

/// Tone of a [BullInfoBar].
enum BullInfoTone {
  /// Warning — uses the warning token colour.
  warning,

  /// Info — uses the info token colour.
  info,
}

/// Left-accent inline info/warning bar (the design's `InfoBar`). **New.**
///
/// A 4px left accent in the [tone] colour, a tinted background, an icon, and a
/// text message.
class BullInfoBar extends StatelessWidget {
  const BullInfoBar({
    super.key,
    required this.message,
    this.tone = BullInfoTone.info,
    this.icon,
  });

  /// The message text.
  final String message;

  /// Visual tone (warning/info).
  final BullInfoTone tone;

  /// Optional leading icon (defaults to a snowflake for info, schedule for
  /// warning).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final accent = tone == BullInfoTone.warning ? colors.warning : colors.info;
    final defaultIcon = tone == BullInfoTone.warning
        ? BullIcons.schedule
        : BullIcons.acUnit;

    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border(left: BorderSide(color: accent, width: 4)),
        borderRadius: BorderRadius.circular(BullRadius.xs),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BullIcon(icon ?? defaultIcon, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.text),
            ),
          ),
        ],
      ),
    );
  }
}
