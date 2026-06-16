import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';

/// Compact icon-over-label button (the design's `ToolBtn`). **New.**
///
/// 56px tall, 4px radius, icon (21) over label (11.5/w600). The [primary]
/// variant uses a red fill; [disabled] dims to 40% and ignores taps.
class BullToolButton extends StatelessWidget {
  const BullToolButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.disabled = false,
  });

  /// Button label.
  final String label;

  /// Button icon glyph.
  final IconData icon;

  /// Tap callback.
  final VoidCallback onPressed;

  /// When true, uses the red primary fill.
  final bool primary;

  /// When true, dims and disables the button.
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final fg = primary ? colors.onPrimary : colors.text;
    final bg = primary ? colors.primary : colors.textMuted.withValues(alpha: 0.12);

    return Semantics(
      button: true,
      label: label,
      enabled: !disabled,
      child: Opacity(
        opacity: disabled ? 0.4 : 1,
        child: IgnorePointer(
          ignoring: disabled,
          child: GestureDetector(
            onTap: onPressed,
            child: Container(
              height: 56,
              constraints: const BoxConstraints(minWidth: 72),
              padding: const EdgeInsets.symmetric(horizontal: BullSpacing.sm),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(BullRadius.xs),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BullIcon(icon, size: 21, color: fg),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
