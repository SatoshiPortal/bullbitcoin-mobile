import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';

/// Square selection box (the design's `SelectBox`). **New.** 22×22, 2px radius,
/// 2px border — red when checked, muted otherwise, and a faint border when
/// [disabled]. Shows a red-filled check when checked.
class BullCheckbox extends StatelessWidget {
  const BullCheckbox({
    super.key,
    required this.checked,
    required this.onChanged,
    this.disabled = false,
  });

  /// Whether the box is checked.
  final bool checked;

  /// Fired with the new value on tap. Null also renders the box inert.
  final ValueChanged<bool>? onChanged;

  /// When true, renders the disabled-styled border (still tappable if
  /// [onChanged] is non-null — frozen tiles allow unfreeze selection).
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final borderColor = disabled
        ? colors.outlineVariant
        : checked
        ? colors.primary
        : colors.textMuted;

    return Semantics(
      checked: checked,
      enabled: onChanged != null,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!checked),
        behavior: HitTestBehavior.opaque,
        // 22px box centered in a 44px tap target for accessibility.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: checked ? colors.primary : null,
                borderRadius: BorderRadius.circular(BullRadius.xs),
                border: Border.all(color: borderColor, width: 2),
              ),
              child: checked
                  ? BullIcon(BullIcons.check, size: 16, color: colors.onPrimary)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
