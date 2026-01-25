import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class SettingsEntryItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
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
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.textColor,
    this.isSuperUser = false,
    this.trailing,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIcon = isSuperUser ? Icons.admin_panel_settings : icon;
    final effectiveIconColor =
        isSuperUser
            ? context.appColors.primary
            : (iconColor ?? context.appColors.text);

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      tileColor: context.appColors.transparent,
      contentPadding: contentPadding,
      leading: Icon(effectiveIcon, color: effectiveIconColor),
      title: Text(
        title,
        style: context.font.bodyLarge?.copyWith(
          color: textColor ?? context.appColors.text,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: context.font.labelSmall?.copyWith(
                color: context.appColors.textMuted,
              ),
            )
          : null,
      trailing: trailing ??
          Icon(
            Icons.chevron_right,
            color: context.appColors.textMuted,
          ),
      onTap: onTap,
    );
  }
}
