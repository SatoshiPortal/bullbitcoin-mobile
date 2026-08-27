import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/features/settings/ui/widgets/testnet_mode_switch.dart';
import 'package:flutter/material.dart';

class BitcoinSettingsScreen extends StatelessWidget {
  const BitcoinSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = settingsItemsOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsBitcoinSettingsTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final item in items.inSection(SettingsItemSection.bitcoin))
                  item.buildTile(
                    context,
                    trailing: item.id == SettingsItemId.testnetMode
                        ? const TestnetModeSwitch()
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
