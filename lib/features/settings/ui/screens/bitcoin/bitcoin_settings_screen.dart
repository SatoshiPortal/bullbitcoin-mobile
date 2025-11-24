import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/ark_setup/router.dart';
// import 'package:bb_mobile/features/ark_setup/router.dart';
import 'package:bb_mobile/features/autoswap/ui/autoswap_settings_router.dart';
import 'package:bb_mobile/features/bip85_entropy/router.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/router.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/routing/electrum_settings_router.dart';
import 'package:bb_mobile/features/import_wallet/router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/settings/ui/widgets/testnet_mode_switch.dart';
import 'package:bb_mobile/features/tor_settings/ui/tor_settings_router.dart';
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
      appBar: AppBar(title: const Text('Bitcoin Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SettingsEntryItem(
                  icon: Icons.account_balance_wallet,
                  title: 'Wallets',
                  onTap: () {
                    context.pushNamed(
                      SettingsRoute.walletDetailsWalletList.name,
                    );
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.settings_input_component,
                  title: 'Electrum Server Settings',
                  onTap: () {
                    context.pushNamed(
                      ElectrumSettingsRoute.electrumSettings.name,
                    );
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.security,
                  title: 'Tor Settings',
                  onTap: () {
                    context.pushNamed(
                      TorSettingsRoute.torSettings.name,
                    );
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.swap_horiz,
                  title: 'Auto Transfer Settings',
                  onTap: () {
                    AutoSwapSettingsRouter.showAutoSwapSettings(context);
                  },
                ),
                if (hasLegacySeeds)
                  SettingsEntryItem(
                    icon: Icons.vpn_key,
                    title: 'Legacy Seeds',
                    onTap: () {
                      context.pushNamed(SettingsRoute.legacySeeds.name);
                    },
                  ),
                SettingsEntryItem(
                  icon: Icons.download,
                  title: 'Import Wallet',
                  onTap:
                      () => context.pushNamed(
                        ImportWalletRoute.importWalletHome.name,
                      ),
                ),
                SettingsEntryItem(
                  icon: Icons.satellite_alt,
                  title: 'Broadcast Transaction',
                  onTap:
                      () => context.pushNamed(
                        BroadcastSignedTxRoute.broadcastHome.name,
                      ),
                ),
                if (isSuperuser)
                  const SettingsEntryItem(
                    icon: Icons.science,
                    title: 'Testnet Mode',
                    isSuperUser: true,
                    trailing: TestnetModeSwitch(),
                  ),
                if (isSuperuser && isDevModeEnabled)
                  SettingsEntryItem(
                    icon: Icons.science,
                    title: 'BIP85 Deterministic Entropies',
                    isSuperUser: isSuperuser && isDevModeEnabled,
                    onTap:
                        () =>
                            context.pushNamed(Bip85EntropyRoute.bip85Home.name),
                  ),
                if (isSuperuser && isDevModeEnabled)
                  SettingsEntryItem(
                    icon: Icons.science,
                    title: 'Ark',
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
