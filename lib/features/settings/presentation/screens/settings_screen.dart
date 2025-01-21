import 'package:bb_mobile/features/settings/router/settings_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              ListTile(
                title: const Text('Pin Code'),
                onTap: () {
                  GoRouter.of(context).pushNamed(SettingsRoute.pinCode.name);
                },
                trailing: const Icon(Icons.chevron_right),
              ),
              ListTile(
                title: const Text('Fiat Currency'),
                onTap: () {},
                trailing: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
