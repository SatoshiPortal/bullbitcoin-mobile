import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Compact icon-over-label button (the design's `ToolBtn`). **New.**
///
/// At least 56px tall, growing with the localized label and text scale. The [primary]
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
    final bg = primary
        ? colors.primary
        : colors.textMuted.withValues(alpha: 0.12);

    final radius = BorderRadius.circular(context.bullShapes.button);

    // One node: the label and button role merge with the InkWell's tap and
    // focus actions.
    return MergeSemantics(
      child: Semantics(
        button: true,
        label: label,
        enabled: !disabled,
        child: Opacity(
          opacity: disabled ? 0.4 : 1,
          child: IgnorePointer(
            ignoring: disabled,
            // Material + InkWell: reachable with Tab, activated with Enter or
            // Space, and focus/hover are drawn as an overlay on the same shape.
            child: Material(
              color: bg,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: disabled ? null : onPressed,
                canRequestFocus: !disabled,
                borderRadius: radius,
                focusColor: fg.withValues(alpha: 0.2),
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 72,
                    minHeight: 56,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: BullSpacing.sm,
                    vertical: BullSpacing.sm,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      BullIcon(icon, size: 21, color: fg),
                      const SizedBox(height: 4),
                      // The label is the node's name: the visible text would
                      // read it a second time.
                      ExcludeSemantics(
                        child: Text(
                          label,
                          style: context.bullType.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
