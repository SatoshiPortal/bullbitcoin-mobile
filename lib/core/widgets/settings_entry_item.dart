import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class SettingsEntryItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;
  final bool isSuperUser;
  final Widget? trailing;
  final EdgeInsetsGeometry? contentPadding;

  const SettingsEntryItem({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.iconColor,
    this.textColor,
    this.isSuperUser = false,
    this.trailing,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIcon = isSuperUser ? Icons.admin_panel_settings : icon;
    final effectiveIconColor =
        isSuperUser
            ? context.appColors.primary
            : (iconColor ?? context.appColors.onSurface);

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      tileColor: context.appColors.transparent,
      contentPadding: contentPadding,
      leading: Icon(effectiveIcon, color: effectiveIconColor),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: textColor ?? context.appColors.onSurface,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
