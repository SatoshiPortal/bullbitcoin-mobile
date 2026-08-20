import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/features/settings/ui/widgets/testnet_mode_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BitcoinSettingsScreen extends StatelessWidget {
  const BitcoinSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isSuperuser = context.select(
      (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
    );
    final isDevModeEnabled = context.select(
      (SettingsCubit cubit) => cubit.state.isDevModeEnabled ?? false,
    );
    final items = buildSettingsItems(
      localization: context.loc,
      exchangeTitle: context.loc.settingsExchangeSettingsTitle,
      isSuperuser: isSuperuser,
      isDevModeEnabled: isDevModeEnabled,
    );

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
