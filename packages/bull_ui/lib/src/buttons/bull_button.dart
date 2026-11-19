import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/src/layout/gap.dart';

/// Button size variants.
enum BullButtonSize {
  /// Compact button (fixed width by default).
  small,

  /// Full-width / large button.
  large,
}

enum _BullButtonRole { primary, secondary }

/// Themed action button. Prefer [BullButton.primary] and [BullButton.secondary].
/// Legacy colour-based constructors remain available during the Ark migration.
class BullButton extends StatelessWidget {
  const BullButton.primary({
    super.key,
    required this.label,
    required VoidCallback? onPressed,
    this.size = BullButtonSize.large,
    this.iconData,
    this.iconFirst = false,
    this.compact = false,
    this.width,
    this.height,
    this.textStyle,
  }) : _role = _BullButtonRole.primary,
       onPressed = onPressed ?? _ignorePress,
       disabled = onPressed == null,
       bgColor = null,
       textColor = null,
       outlined = false,
       borderColor = null;

  const BullButton.secondary({
    super.key,
    required this.label,
    required VoidCallback? onPressed,
    this.size = BullButtonSize.large,
    this.iconData,
    this.iconFirst = false,
    this.compact = false,
    this.width,
    this.height,
    this.textStyle,
  }) : _role = _BullButtonRole.secondary,
       onPressed = onPressed ?? _ignorePress,
       disabled = onPressed == null,
       bgColor = null,
       textColor = null,
       outlined = false,
       borderColor = null;

  const BullButton.big({
    super.key,
    required this.label,
    required this.onPressed,
    required Color this.bgColor,
    required Color this.textColor,
    this.iconData,
    this.iconFirst = false,
    this.outlined = false,
    this.borderColor,
    this.disabled = false,
    this.height,
    this.width,
    this.textStyle,
    this.compact = false,
  }) : size = BullButtonSize.large,
       _role = null;

  const BullButton.small({
    super.key,
    required this.label,
    required this.onPressed,
    required Color this.bgColor,
    required Color this.textColor,
    this.iconData,
    this.iconFirst = false,
    this.outlined = false,
    this.borderColor,
    this.disabled = false,
    this.height,
    this.width,
    this.textStyle,
    this.compact = false,
  }) : size = BullButtonSize.small,
       _role = null;

  /// Optional leading/trailing icon glyph.
  final IconData? iconData;

  /// Button label.
  final String label;

  /// Explicit legacy fill; role constructors resolve it from the theme.
  final Color? bgColor;

  /// Explicit legacy foreground; null for theme-resolved role constructors.
  final Color? textColor;

  /// When true, the icon precedes the label.
  final bool iconFirst;

  /// Legacy-compatible callback. Check [disabled] for availability.
  /// A disabled role button exposes an inert callback and has no tap handler.
  final VoidCallback onPressed;

  /// When true, draws a border instead of a solid fill.
  final bool outlined;

  /// Size variant.
  final BullButtonSize size;

  /// Border colour when [outlined]; defaults to [textColor].
  final Color? borderColor;

  /// When true, dims the button and ignores taps.
  final bool disabled;

  /// Requested height. Role buttons keep a minimum 48 dp target.
  final double? height;

  /// Overrides the default width.
  final double? width;

  /// Overrides the default label text style.
  final TextStyle? textStyle;

  /// Shrink to the label instead of the fixed small width, for a chip-sized
  /// action that sits in a row or a wrap with others.
  final bool compact;

  final _BullButtonRole? _role;

  static void _ignorePress() {}

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final fill = switch (_role) {
      _BullButtonRole.primary => colors.primary,
      _BullButtonRole.secondary => colors.secondary,
      null => bgColor,
    };
    final foreground = switch (_role) {
      _BullButtonRole.primary => colors.onPrimary,
      _BullButtonRole.secondary => colors.onSecondary,
      null => textColor,
    };
    final radius = BorderRadius.circular(context.bullShapes.button);

    final image = iconData != null
        ? Icon(iconData, size: 20, color: foreground)
        : const SizedBox.shrink();

    final labelStyle =
        textStyle ??
        context.bullType.subtitle.copyWith(fontWeight: FontWeight.w700);
    final labelText = Flexible(
      child: compact && _role != null
          // Dialog actions measure intrinsic widths before laying out.
          ? Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle.copyWith(color: foreground),
            )
          : BullText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
              color: foreground,
            ),
    );

    final button = AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: disabled ? 0.5 : 1,
      child: IgnorePointer(
        ignoring: disabled,
        // Its own ink surface, so the button also works above the navigator.
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: disabled ? null : onPressed,
            borderRadius: radius,
            child: Container(
              height: _role == null
                  ? height ?? (compact ? 36 : 52)
                  : (height ?? (compact ? 48 : 52)).clamp(48, double.infinity),
              constraints: _role == null
                  ? null
                  : const BoxConstraints(minWidth: 48),
              width:
                  width ??
                  (size == BullButtonSize.large || compact ? null : 160),
              padding: compact
                  ? const EdgeInsets.symmetric(horizontal: 16)
                  : height != null
                  ? null
                  : const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: fill,
                border: outlined
                    ? Border.all(
                        color: borderColor ?? foreground ?? colors.text,
                      )
                    : null,
                borderRadius: radius,
              ),
              child: Row(
                mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
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
      ),
    );

    final accessibleButton = Semantics(
      button: true,
      enabled: !disabled,
      child: button,
    );

    return Builder(
      builder: (context) {
        final overlay = Overlay.maybeOf(context);
        // No tooltip for icon-only buttons (empty label → an empty bubble is
        // worse than none) or when there's no overlay to host one.
        if (overlay == null || label.isEmpty) return accessibleButton;
        return Tooltip(
          message: label,
          waitDuration: const Duration(milliseconds: 500),
          child: accessibleButton,
        );
      },
    );
  }
}
