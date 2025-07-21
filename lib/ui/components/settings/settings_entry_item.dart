import 'package:flutter/material.dart';

class SettingsEntryItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;
  final bool isSuperUser;
  final Widget? trailing;

  const SettingsEntryItem({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.iconColor,
    this.textColor,
    this.isSuperUser = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIcon = isSuperUser ? Icons.admin_panel_settings : icon;
    final effectiveIconColor =
        isSuperUser
            ? theme.colorScheme.primary
            : (iconColor ?? theme.colorScheme.onSurface);

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      tileColor: Colors.transparent,
      leading: Icon(effectiveIcon, color: effectiveIconColor),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: textColor ?? theme.colorScheme.onSurface,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
