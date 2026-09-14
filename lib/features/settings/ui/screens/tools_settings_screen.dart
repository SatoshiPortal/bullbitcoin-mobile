import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:flutter/material.dart';

class ToolsSettingsScreen extends StatelessWidget {
  const ToolsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = settingsItemsOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsToolsTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final item in items.inSection(SettingsItemSection.tools))
                  item.buildTile(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
