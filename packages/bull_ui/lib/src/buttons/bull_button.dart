import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/src/layout/gap.dart';

/// Button size variants.
enum BullButtonSize {
  /// Compact button (fixed width by default).
  small,

  /// Full-width / large button.
  large,
}

enum _BullButtonVariant { primary, secondary, danger }

/// A semantic or legacy-sized Bull button.
///
/// Prefer [BullButton.primary], [BullButton.secondary], or [BullButton.danger]
/// for semantic intent. These variants resolve their colours from
/// `context.bull` and support both [BullButtonSize.large] and
/// [BullButtonSize.small]. [BullButton.big] and [BullButton.small] remain
/// available for existing callers that provide explicit colours.
class BullButton extends StatelessWidget {
  const BullButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = BullButtonSize.large,
    this.iconData,
    this.iconFirst = false,
    this.disabled = false,
    this.height,
    this.width,
    this.textStyle,
  }) : bgColor = null,
       textColor = null,
       outlined = false,
       borderColor = null,
       _semanticVariant = _BullButtonVariant.primary;

  const BullButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = BullButtonSize.large,
    this.iconData,
    this.iconFirst = false,
    this.disabled = false,
    this.height,
    this.width,
    this.textStyle,
  }) : bgColor = null,
       textColor = null,
       outlined = true,
       borderColor = null,
       _semanticVariant = _BullButtonVariant.secondary;

  const BullButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = BullButtonSize.large,
    this.iconData,
    this.iconFirst = false,
    this.disabled = false,
    this.height,
    this.width,
    this.textStyle,
  }) : bgColor = null,
       textColor = null,
       outlined = false,
       borderColor = null,
       _semanticVariant = _BullButtonVariant.danger;

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
  }) : size = BullButtonSize.large,
       _semanticVariant = null;

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
  }) : size = BullButtonSize.small,
       _semanticVariant = null;

  /// Optional leading/trailing icon glyph.
  final IconData? iconData;

  /// Button label.
  final String label;

  /// Background fill.
  final Color? bgColor;

  /// Label and icon colour.
  final Color? textColor;

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

  final _BullButtonVariant? _semanticVariant;

  @override
  Widget build(BuildContext context) {
    final colors = _semanticVariant == null ? null : context.bull;
    final resolvedBgColor = switch (_semanticVariant) {
      _BullButtonVariant.primary => colors!.primary,
      _BullButtonVariant.secondary => colors!.surface,
      _BullButtonVariant.danger => colors!.error,
      null => bgColor!,
    };
    final resolvedTextColor = switch (_semanticVariant) {
      _BullButtonVariant.primary => colors!.onPrimary,
      _BullButtonVariant.secondary => colors!.primary,
      _BullButtonVariant.danger => colors!.onError,
      null => textColor!,
    };
    final resolvedBorderColor = borderColor ?? resolvedTextColor;
    final radius = BorderRadius.circular(BullRadius.xxs);

    final image = iconData != null
        ? Icon(iconData, size: 20, color: resolvedTextColor)
        : const SizedBox.shrink();

    final labelText = Flexible(
      child: BullText(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textStyle ?? Theme.of(context).textTheme.headlineLarge,
        color: resolvedTextColor,
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
              color: resolvedBgColor,
              border: outlined ? Border.all(color: resolvedBorderColor) : null,
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
        // No tooltip for icon-only buttons (empty label → an empty bubble is
        // worse than none) or when there's no overlay to host one.
        if (overlay == null || label.isEmpty) return button;
        return Tooltip(
          message: label,
          waitDuration: const Duration(milliseconds: 500),
          child: button,
        );
      },
    );
  }
}
