import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:flutter/material.dart';

class WalletSettingsScreen extends StatelessWidget {
  const WalletSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = settingsItemsOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsWalletSettingsTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final id in walletSettingsItemOrder)
                  items.byId(id).buildTile(context),
                for (final item in items.inSection(SettingsItemSection.wallet))
                  if (!walletSettingsItemOrder.contains(item.id))
                    item.buildTile(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
