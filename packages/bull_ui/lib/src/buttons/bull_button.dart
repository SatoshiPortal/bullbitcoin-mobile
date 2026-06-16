import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Button size variants.
enum BullButtonSize {
  /// Compact button (fixed width by default).
  small,

  /// Full-width / large button.
  large,
}

/// Primary button — duplicated from `core/widgets/buttons/button.dart`.
///
/// Use [BullButton.big] / [BullButton.small]. Supports an optional icon,
/// outlined and disabled states. Colours are supplied by the caller (read from
/// `context.bull`) so the widget itself hardcodes none.
class BullButton extends StatelessWidget {
  const BullButton.big({
    super.key,
    required this.label,
    required this.onPressed,
    required this.bgColor,
    required this.textColor,
    this.iconData,
    this.iconFirst = false,
    this.outlined = false,
    this.borderColor,
    this.disabled = false,
    this.height,
    this.width,
    this.textStyle,
  }) : size = BullButtonSize.large;

  const BullButton.small({
    super.key,
    required this.label,
    required this.onPressed,
    required this.bgColor,
    required this.textColor,
    this.iconData,
    this.iconFirst = false,
    this.outlined = false,
    this.borderColor,
    this.disabled = false,
    this.height,
    this.width,
    this.textStyle,
  }) : size = BullButtonSize.small;

  /// Optional leading/trailing icon glyph.
  final IconData? iconData;

  /// Button label.
  final String label;

  /// Background fill.
  final Color bgColor;

  /// Label and icon colour.
  final Color textColor;

  /// When true, the icon precedes the label.
  final bool iconFirst;

  /// Tap callback.
  final VoidCallback onPressed;

  /// When true, draws a border instead of a solid fill.
  final bool outlined;

  /// Size variant.
  final BullButtonSize size;

  /// Border colour when [outlined]; defaults to [textColor].
  final Color? borderColor;

  /// When true, dims the button and ignores taps.
  final bool disabled;

  /// Overrides the default height.
  final double? height;

  /// Overrides the default width.
  final double? width;

  /// Overrides the default label text style.
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(BullRadius.button);

    final image = iconData != null
        ? Icon(iconData, size: 20, color: textColor)
        : const SizedBox.shrink();

    final labelText = Flexible(
      child: BullText(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textStyle ?? BullTextStyles.title,
        color: textColor,
      ),
    );

    final button = AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: disabled ? 0.5 : 1,
      child: IgnorePointer(
        ignoring: disabled,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: radius,
          child: Container(
            height: height ?? 52,
            width: width ?? (size == BullButtonSize.large ? null : 160),
            padding: height != null
                ? null
                : const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              border: outlined
                  ? Border.all(color: borderColor ?? textColor)
                  : null,
              borderRadius: radius,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (iconData == null) ...[
                  labelText,
                ] else if (label.isEmpty) ...[
                  image,
                ] else ...[
                  if (iconFirst) ...[
                    image,
                    const Gap(10),
                    labelText,
                  ] else ...[
                    labelText,
                    const Gap(10),
                    image,
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Builder(
      builder: (context) {
        final overlay = Overlay.maybeOf(context);
        if (overlay == null) return button;
        return Tooltip(
          message: label,
          waitDuration: const Duration(milliseconds: 500),
          child: button,
        );
      },
    );
  }
}
