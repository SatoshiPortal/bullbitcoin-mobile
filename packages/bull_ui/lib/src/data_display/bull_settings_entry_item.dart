import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:material_ui/material_ui.dart';

/// A settings-list row: leading icon, title, trailing chevron.
///
/// When [isSuperUser] is true the icon is replaced with an admin glyph tinted
/// brand red.
class BullSettingsEntryItem extends StatelessWidget {
  const BullSettingsEntryItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.textColor,
    this.isSuperUser = false,
    this.trailing,
    this.contentPadding,
    this.leading,
  });

  /// Leading icon glyph.
  final IconData icon;

  /// Row title.
  final String title;

  /// Optional secondary line rendered under [title].
  final String? subtitle;

  /// Tap callback.
  final VoidCallback? onTap;

  /// Icon colour override.
  final Color? iconColor;

  /// Title colour override.
  final Color? textColor;

  /// Renders the super-user (admin) variant.
  final bool isSuperUser;

  /// Trailing widget (defaults to a chevron).
  final Widget? trailing;

  /// Content padding override.
  final EdgeInsetsGeometry? contentPadding;

  /// Leading widget drawn instead of [icon], for a glyph no icon font has.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final effectiveIcon = isSuperUser ? Icons.admin_panel_settings : icon;
    final effectiveIconColor = isSuperUser
        ? colors.primary
        : (iconColor ?? colors.onSurface);

    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.bullShapes.card),
      ),
      tileColor: colors.transparent,
      contentPadding: contentPadding,
      leading: isSuperUser
          ? Icon(effectiveIcon, color: effectiveIconColor)
          : leading ?? Icon(effectiveIcon, color: effectiveIconColor),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.bullType.body
            .copyWith(fontWeight: FontWeight.w500)
            .copyWith(color: textColor ?? colors.onSurface),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.bullType.label
                  .copyWith(fontWeight: FontWeight.w400)
                  .copyWith(color: colors.textMuted),
            ),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
