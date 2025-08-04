import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SettingsEntryItem(
                  icon: Icons.article,
                  title: 'Logs',
                  onTap: () {
                    context.pushNamed(SettingsRoute.logs.name);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
