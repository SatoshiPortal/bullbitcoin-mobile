import 'package:bb_mobile/core/presentation/build_context_extensions.dart';
import 'package:bb_mobile/features/settings/router/settings_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.settingsScreenTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              ListTile(
                title: Text(context.loc.pinCodeSettingsButtonLabel),
                onTap: () {
                  GoRouter.of(context).pushNamed(SettingsRoute.pinCode.name);
                },
                trailing: const Icon(Icons.chevron_right),
              ),
              ListTile(
                title: Text(context.loc.languageSettingsButtonLabel),
                onTap: () {
                  GoRouter.of(context).pushNamed(SettingsRoute.language.name);
                },
                trailing: const Icon(Icons.chevron_right),
              ),
              ListTile(
                title: Text(context.loc.fiatCurrencySettingsButtonLabel),
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
