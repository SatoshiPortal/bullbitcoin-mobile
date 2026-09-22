import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:flutter/material.dart';

class SettingsGroupScreen extends StatelessWidget {
  final String title;
  final SettingsItemSection section;

  const SettingsGroupScreen({
    super.key,
    required this.title,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    final items = settingsItemsOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final item in items.inSection(section))
              item.buildTile(context),
          ],
        ),
      ),
    );
  }
}
