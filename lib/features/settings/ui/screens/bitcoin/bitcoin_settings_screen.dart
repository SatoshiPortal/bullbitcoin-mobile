import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/ark_setup/router.dart';
// import 'package:bb_mobile/features/ark_setup/router.dart';
import 'package:bb_mobile/features/bip85_entropy/router.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/router.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/routing/electrum_settings_router.dart';
import 'package:bb_mobile/features/import_wallet/router.dart';
import 'package:bb_mobile/features/mempool_settings/router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/settings/ui/widgets/testnet_mode_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class BitcoinSettingsScreen extends StatelessWidget {
  const BitcoinSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isSuperuser = context.select(
      (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
    );
    final hasLegacySeeds = context.select(
      (SettingsCubit cubit) => cubit.state.hasLegacySeeds ?? false,
    );
    final isDevModeEnabled = context.select(
      (SettingsCubit cubit) => cubit.state.isDevModeEnabled ?? false,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsBitcoinSettingsTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SettingsEntryItem(
                  icon: Icons.account_balance_wallet,
                  title: context.loc.bitcoinSettingsWalletsTitle,
                  onTap: () {
                    context.pushNamed(
                      SettingsRoute.walletDetailsWalletList.name,
                    );
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.settings_input_component,
                  title: context.loc.bitcoinSettingsElectrumServerTitle,
                  onTap: () {
                    context.pushNamed(
                      ElectrumSettingsRoute.electrumSettings.name,
                    );
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.analytics,
                  title: context.loc.bitcoinSettingsMempoolServerTitle,
                  onTap: () {
                    context.pushNamed(MempoolSettingsRoute.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.swap_horiz,
                  title: context.loc.bitcoinSettingsAutoTransferTitle,
                  onTap: () {
                    context.pushNamed(SettingsRoute.autoswapSettings.name);
                  },
                ),
                if (hasLegacySeeds)
                  SettingsEntryItem(
                    icon: Icons.vpn_key,
                    title: context.loc.bitcoinSettingsLegacySeedsTitle,
                    onTap: () {
                      context.pushNamed(SettingsRoute.legacySeeds.name);
                    },
                  ),
                SettingsEntryItem(
                  icon: Icons.download,
                  title: context.loc.bitcoinSettingsImportWalletTitle,
                  onTap: () => context.pushNamed(
                    ImportWalletRoute.importWalletHome.name,
                  ),
                ),
                SettingsEntryItem(
                  icon: Icons.satellite_alt,
                  title: context.loc.bitcoinSettingsBroadcastTransactionTitle,
                  onTap: () => context.pushNamed(
                    BroadcastSignedTxRoute.broadcastHome.name,
                  ),
                ),
                if (isSuperuser)
                  SettingsEntryItem(
                    icon: Icons.science,
                    title: context.loc.bitcoinSettingsTestnetModeTitle,
                    isSuperUser: true,
                    trailing: const TestnetModeSwitch(),
                  ),
                if (isSuperuser)
                  SettingsEntryItem(
                    icon: Icons.vpn_key,
                    title: 'Seed Viewer',
                    isSuperUser: true,
                    onTap: () {
                      context.pushNamed(SettingsRoute.allSeedView.name);
                    },
                  ),
                if (isSuperuser && isDevModeEnabled)
                  SettingsEntryItem(
                    icon: Icons.science,
                    title: context.loc.bitcoinSettingsBip85EntropiesTitle,
                    isSuperUser: isSuperuser && isDevModeEnabled,
                    onTap: () =>
                        context.pushNamed(Bip85EntropyRoute.bip85Home.name),
                  ),
                if (isSuperuser && isDevModeEnabled)
                  SettingsEntryItem(
                    icon: Icons.science,
                    title: context.loc.settingsArkTitle,
                    isSuperUser: isSuperuser && isDevModeEnabled,
                    onTap: () => context.pushNamed(ArkSetupRoute.arkSetup.name),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
