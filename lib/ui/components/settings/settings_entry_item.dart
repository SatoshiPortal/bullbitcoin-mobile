import 'package:flutter/material.dart';

class SettingsEntryItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;

  const SettingsEntryItem({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      tileColor: Colors.transparent,
      leading: Icon(icon, color: iconColor ?? theme.colorScheme.onSurface),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: textColor ?? theme.colorScheme.onSurface,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
