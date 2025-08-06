import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class AllSettingsScreen extends StatelessWidget {
  const AllSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final appVersion = context.select(
      (SettingsCubit cubit) => cubit.state.appVersion,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsScreenTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SettingsEntryItem(
                  icon: Icons.account_balance_wallet,
                  title: 'Exchange Settings',
                  onTap: () {
                    context.pushNamed(SettingsRoute.exchangeSettings.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.save_alt,
                  title: 'Wallet Backup',
                  onTap: () {
                    context.pushNamed(SettingsRoute.backupSettings.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.currency_bitcoin,
                  title: 'Bitcoin Settings',
                  onTap: () {
                    context.pushNamed(SettingsRoute.bitcoinSettings.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.security,
                  title: 'Security Pin',
                  onTap: () {
                    context.pushNamed(SettingsRoute.pinCode.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.attach_money,
                  title: 'Currency',
                  onTap: () {
                    context.pushNamed(SettingsRoute.currency.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.settings,
                  title: 'App Settings',
                  onTap: () {
                    context.pushNamed(SettingsRoute.appSettings.name);
                  },
                ),

                SettingsEntryItem(
                  icon: Icons.description,
                  title: 'Terms of Service',
                  onTap: () {
                    final url = Uri.parse(
                      SettingsConstants.termsAndConditionsLink,
                    );
                    launchUrl(url, mode: LaunchMode.inAppBrowserView);
                  },
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
