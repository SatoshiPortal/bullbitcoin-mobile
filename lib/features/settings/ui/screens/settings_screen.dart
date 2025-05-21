import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/electrum_settings/ui/electrum_settings_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/settings/ui/widgets/sats_bitcoin_unit_switch.dart';
import 'package:bb_mobile/features/settings/ui/widgets/testnet_mode_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isSuperuser = context.select(
      (SettingsCubit cubit) => cubit.state?.isSuperuser ?? false,
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsScreenTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (isSuperuser)
                ListTile(
                  title: Text(context.loc.testnetModeSettingsLabel),
                  trailing: const TestnetModeSwitch(),
                ),
              ListTile(
                title: Text(context.loc.satsBitcoinUnitSettingsLabel),
                trailing: const SatsBitcoinUnitSwitch(),
              ),
              ListTile(
                title: Text(context.loc.backupSettingsLabel),
                onTap: () {
                  context.pushNamed(SettingsRoute.backupSettings.name);
                },
                trailing: const Icon(Icons.chevron_right),
              ),
              if (isSuperuser)
                ListTile(
                  title: Text(context.loc.electrumServerSettingsLabel),
                  onTap: () {
                    ElectrumSettingsRouter.showElectrumServerSettings(context);
                  },
                  trailing: const Icon(Icons.chevron_right),
                ),
              ListTile(
                title: Text(context.loc.pinCodeSettingsLabel),
                onTap: () {
                  context.pushNamed(SettingsRoute.pinCode.name);
                },
                trailing: const Icon(Icons.chevron_right),
              ),
              if (isSuperuser)
                ListTile(
                  title: Text(context.loc.languageSettingsLabel),
                  onTap: () {
                    // context.pushNamed(SettingsSubroute.language.name);
                  },
                  trailing: const Icon(Icons.chevron_right),
                ),
              if (isSuperuser)
                ListTile(
                  title: Text(context.loc.fiatCurrencySettingsLabel),
                  onTap: () {
                    //context.pushNamed(SettingsSubroute.currency.name);
                  },
                  trailing: const Icon(Icons.chevron_right),
                ),
              ListTile(
                title: const Text('Logs'),
                onTap: () {
                  context.pushNamed(SettingsRoute.logs.name);
                },
                trailing: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
