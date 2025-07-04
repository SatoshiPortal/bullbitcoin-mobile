import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/autoswap/ui/autoswap_settings_router.dart';
import 'package:bb_mobile/features/electrum_settings/ui/electrum_settings_router.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/settings/ui/widgets/testnet_mode_switch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSuperuser = context.select(
      (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
    );
    final appVersion = context.select(
      (SettingsCubit cubit) => cubit.state.appVersion,
    );
    final hasLegacySeeds = context.select(
      (SettingsCubit cubit) => cubit.state.hasLegacySeeds ?? false,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsScreenTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                  tileColor: Colors.transparent,
                  title: Text(context.loc.backupSettingsLabel),
                  onTap: () {
                    context.pushNamed(SettingsRoute.backupSettings.name);
                  },
                  trailing: const Icon(Icons.chevron_right),
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                  tileColor: Colors.transparent,
                  title: const Text('Wallet details'),
                  onTap: () {
                    context.pushNamed(
                      SettingsRoute.walletDetailsWalletList.name,
                    );
                  },
                  trailing: const Icon(Icons.chevron_right),
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                  tileColor: Colors.transparent,
                  title: Text(context.loc.electrumServerSettingsLabel),
                  onTap: () {
                    ElectrumSettingsRouter.showElectrumServerSettings(context);
                  },
                  trailing: const Icon(Icons.chevron_right),
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                  tileColor: Colors.transparent,
                  title: Text(context.loc.pinCodeSettingsLabel),
                  onTap: () {
                    context.pushNamed(SettingsRoute.pinCode.name);
                  },
                  trailing: const Icon(Icons.chevron_right),
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                  tileColor: Colors.transparent,
                  title: const Text('Currency'),
                  onTap: () {
                    context.pushNamed(SettingsRoute.currency.name);
                  },
                  trailing: const Icon(Icons.chevron_right),
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                  tileColor: Colors.transparent,
                  title: const Text('Auto Swap Settings'),
                  onTap: () {
                    AutoSwapSettingsRouter.showAutoSwapSettings(context);
                  },
                  trailing: const Icon(Icons.chevron_right),
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                  tileColor: Colors.transparent,
                  title: const Text('Logs'),
                  onTap: () {
                    context.pushNamed(SettingsRoute.logs.name);
                  },
                  trailing: const Icon(Icons.chevron_right),
                ),
                if (hasLegacySeeds)
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                    tileColor: Colors.transparent,
                    title: const Text('Legacy Seeds'),
                    onTap: () {
                      context.pushNamed(SettingsRoute.legacySeeds.name);
                    },
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                  tileColor: Colors.transparent,
                  title: const Text('Terms & Conditions'),
                  onTap: () {
                    final url = Uri.parse(
                      SettingsConstants.termsAndConditionsLink,
                    );
                    launchUrl(url, mode: LaunchMode.inAppBrowserView);
                  },
                  trailing: const Icon(Icons.chevron_right),
                ),
                if (isSuperuser && kDebugMode)
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                    tileColor: Colors.transparent,
                    title: const Text('Experimental / Danger Zone'),
                    onTap:
                        () =>
                            context.pushNamed(SettingsRoute.experimental.name),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                if (isSuperuser)
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                    tileColor: Colors.transparent,
                    title: Text(context.loc.testnetModeSettingsLabel),
                    trailing: const TestnetModeSwitch(),
                  ),
                if (isSuperuser)
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                    tileColor: Colors.transparent,
                    title: Text(context.loc.languageSettingsLabel),
                    onTap: () {
                      context.pushNamed(SettingsRoute.language.name);
                    },
                    trailing: const Icon(Icons.chevron_right),
                  ),
                if (isSuperuser)
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                    tileColor: Colors.transparent,
                    title: const Text('Import watch-only'),
                    onTap:
                        () => context.pushNamed(
                          ImportWatchOnlyRoutes.import.name,
                        ),
                    trailing: const Icon(Icons.qr_code_2),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 150,
        padding: EdgeInsets.zero,
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (appVersion != null)
                ListTile(
                  tileColor: theme.colorScheme.secondaryFixedDim,
                  title: Center(
                    child: Text(
                      'App version: $appVersion',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: appVersion));
                  },
                ),
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    InkWell(
                      onTap: () {
                        final url = Uri.parse(
                          SettingsConstants.telegramSupportLink,
                        );
                        launchUrl(url, mode: LaunchMode.externalApplication);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(FontAwesomeIcons.telegram),
                          const Gap(8),
                          Text(
                            'Telegram',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        final url = Uri.parse(
                          SettingsConstants.githubSupportLink,
                        );
                        launchUrl(url, mode: LaunchMode.externalApplication);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(FontAwesomeIcons.github),
                          const Gap(8),
                          Text(
                            'Github',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
