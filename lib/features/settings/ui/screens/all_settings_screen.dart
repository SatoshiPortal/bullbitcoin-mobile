import 'dart:io';

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/status_check/presentation/cubit.dart';
import 'package:bb_mobile/features/status_check/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class AllSettingsScreen extends StatefulWidget {
  const AllSettingsScreen({super.key});

  @override
  State<AllSettingsScreen> createState() => _AllSettingsScreenState();
}

class _AllSettingsScreenState extends State<AllSettingsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ServiceStatusCubit>().checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final appVersion = context.select(
      (SettingsCubit cubit) => cubit.state.appVersion,
    );

    final serviceStatusLoading = context.select(
      (ServiceStatusCubit cubit) => cubit.state.isLoading,
    );

    final serviceStatus = context.select(
      (ServiceStatusCubit cubit) => cubit.state.serviceStatus,
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
                  title: context.loc.settingsExchangeSettingsTitle,
                  onTap: () {
                    if (Platform.isIOS) {
                      final isSuperuser =
                          context.read<SettingsCubit>().state.isSuperuser ??
                          false;
                      if (isSuperuser) {
                        final notLoggedIn =
                            context.read<ExchangeCubit>().state.notLoggedIn;
                        if (notLoggedIn) {
                          context.goNamed(ExchangeRoute.exchangeLanding.name);
                        } else {
                          context.pushNamed(
                            SettingsRoute.exchangeSettings.name,
                          );
                        }
                      } else {
                        context.goNamed(ExchangeRoute.exchangeLanding.name);
                      }
                    } else {
                      final notLoggedIn =
                          context.read<ExchangeCubit>().state.notLoggedIn;
                      if (notLoggedIn) {
                        context.goNamed(ExchangeRoute.exchangeLanding.name);
                      } else {
                        context.pushNamed(SettingsRoute.exchangeSettings.name);
                      }
                    }
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.save_alt,
                  title: context.loc.settingsWalletBackupTitle,
                  onTap: () {
                    context.pushNamed(SettingsRoute.backupSettings.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.currency_bitcoin,
                  title: context.loc.settingsBitcoinSettingsTitle,
                  onTap: () {
                    context.pushNamed(SettingsRoute.bitcoinSettings.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.security,
                  title: context.loc.settingsSecurityPinTitle,
                  onTap: () {
                    context.pushNamed(SettingsRoute.pinCode.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.attach_money,
                  title: context.loc.settingsCurrencyTitle,
                  onTap: () {
                    context.pushNamed(SettingsRoute.currency.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.palette,
                  title: 'Theme',
                  onTap: () {
                    context.pushNamed(SettingsRoute.theme.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.settings,
                  title: context.loc.settingsAppSettingsTitle,
                  onTap: () {
                    context.pushNamed(SettingsRoute.appSettings.name);
                  },
                ),

                SettingsEntryItem(
                  icon: Icons.description,
                  title: context.loc.settingsTermsOfServiceTitle,
                  onTap: () {
                    final url = Uri.parse(
                      SettingsConstants.termsAndConditionsLink,
                    );
                    launchUrl(url, mode: LaunchMode.inAppBrowserView);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.monitor_heart,
                  iconColor:
                      serviceStatusLoading
                          ? Colors.grey
                          : serviceStatus.allServicesOnline
                          ? Colors.green
                          : Colors.red,
                  title: context.loc.settingsServicesStatusTitle,
                  onTap: () {
                    context.pushNamed(StatusCheckRoute.serviceStatus.name);
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
                      '${context.loc.settingsAppVersionLabel}$appVersion',
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
                            context.loc.settingsTelegramLabel,
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
                            context.loc.settingsGithubLabel,
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
