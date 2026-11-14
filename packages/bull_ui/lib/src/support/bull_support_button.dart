import 'package:bull_ui/src/buttons/bull_button.dart';
import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/layout/gap.dart';
import 'package:bull_ui/src/support/bull_support_scope.dart';
import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:material_ui/material_ui.dart';

enum _BullSupportButtonVariant { big, icon, text, tile }

/// A "contact support" entry point that runs the app's support action.
///
/// The action comes from the nearest [BullSupportScope]: the button never
/// decides what support means. Without a scope it renders disabled and a tap
/// does nothing.
class BullSupportButton extends StatelessWidget {
  /// Full-width [BullButton.big]. Defaults to the secondary colours.
  const BullSupportButton.big({
    super.key,
    required this.label,
    this.message,
    this.icon,
    this.bgColor,
    this.textColor,
  }) : color = null,
       _variant = _BullSupportButtonVariant.big;

  /// Compact icon button for top bars. Defaults to a chat bubble in
  /// `onPrimary`; [label] becomes its tooltip and semantics label.
  const BullSupportButton.icon({
    super.key,
    required this.label,
    this.message,
    this.icon,
    this.color,
  }) : bgColor = null,
       textColor = null,
       _variant = _BullSupportButtonVariant.icon;

  /// Text-only button in the primary colour.
  const BullSupportButton.text({super.key, required this.label, this.message})
    : icon = null,
      color = null,
      bgColor = null,
      textColor = null,
      _variant = _BullSupportButtonVariant.text;

  /// Icon above its label, for a footer row. Defaults to a headset in
  /// `onSurface`.
  const BullSupportButton.tile({
    super.key,
    required this.label,
    this.message,
    this.icon,
    this.color,
  }) : bgColor = null,
       textColor = null,
       _variant = _BullSupportButtonVariant.tile;

  /// Visible label, or the tooltip of [BullSupportButton.icon].
  final String label;

  /// Optional draft forwarded to the support action; `null` = app default.
  final String? message;

  /// Overrides the variant's default glyph (a trailing icon for `.big`).
  final IconData? icon;

  /// Icon (and `.tile` label) colour for `.icon` and `.tile`.
  final Color? color;

  /// Background of `.big`; defaults to `context.bull.secondary`.
  final Color? bgColor;

  /// Label colour of `.big`; defaults to `context.bull.onSecondary`.
  final Color? textColor;

  final _BullSupportButtonVariant _variant;

  static const double _disabledOpacity = 0.5;

  @override
  Widget build(BuildContext context) {
    final scope = BullSupportScope.maybeOf(context);
    final VoidCallback? onTap = scope == null
        ? null
        : () => scope.onContactSupport(context, message: message);

    switch (_variant) {
      case _BullSupportButtonVariant.big:
        return BullButton.big(
          label: label,
          iconData: icon,
          bgColor: bgColor ?? context.bull.secondary,
          textColor: textColor ?? context.bull.onSecondary,
          onPressed: onTap ?? () {},
          disabled: onTap == null,
        );
      case _BullSupportButtonVariant.icon:
        final button = IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
          // Tooltip needs an Overlay; fall back to a plain semantics label.
          tooltip: Overlay.maybeOf(context) == null ? null : label,
          icon: BullIcon(
            icon ?? BullIcons.chatBubbleOutline,
            color: color ?? context.bull.onPrimary,
            size: 24,
          ),
          onPressed: onTap,
        );
        final labelled = Overlay.maybeOf(context) == null
            ? Semantics(label: label, button: true, child: button)
            : button;
        return _dimWhenDisabled(enabled: onTap != null, child: labelled);
      case _BullSupportButtonVariant.text:
        return _dimWhenDisabled(
          enabled: onTap != null,
          child: TextButton(
            onPressed: onTap,
            child: BullText(
              label,
              style: context.bullText.bodyMedium,
              color: context.bull.primary,
            ),
          ),
        );
      case _BullSupportButtonVariant.tile:
        final foreground = color ?? context.bull.onSurface;
        return _dimWhenDisabled(
          enabled: onTap != null,
          child: Semantics(
            button: true,
            enabled: onTap != null,
            child: InkWell(
              onTap: onTap,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BullIcon(icon ?? BullIcons.headsetMic, color: foreground),
                  const Gap(8),
                  BullText(
                    label,
                    style: context.bullText.bodyMedium,
                    color: foreground,
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  static Widget _dimWhenDisabled({
    required bool enabled,
    required Widget child,
  }) {
    if (enabled) return child;
    return Opacity(opacity: _disabledOpacity, child: child);
  }
}
