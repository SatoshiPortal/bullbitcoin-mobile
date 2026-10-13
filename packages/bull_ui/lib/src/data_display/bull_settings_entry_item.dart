import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';

/// A settings-list row: leading icon, title, trailing chevron — duplicated
/// from `core/widgets/settings_entry_item.dart` (`SettingsEntryItem`).
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

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final effectiveIcon = isSuperUser ? Icons.admin_panel_settings : icon;
    final effectiveIconColor = isSuperUser
        ? colors.primary
        : (iconColor ?? colors.onSurface);

    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BullRadius.xxs),
      ),
      tileColor: colors.transparent,
      contentPadding: contentPadding,
      leading: Icon(effectiveIcon, color: effectiveIconColor),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: textColor ?? colors.onSurface,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
            ),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
