import 'dart:io';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
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
      appBar: AppBar(
        title: BBText(
          context.loc.settingsScreenTitle,
          style: context.font.headlineMedium,
          color: context.appColors.text,
        ),
        backgroundColor: context.appColors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.appColors.text),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SettingsEntryItem(
                  icon: Icons.currency_exchange,
                  title: context.loc.settingsExchangeSettingsTitle,
                  trailing: Icon(
                    Icons.chevron_right,
                    color: context.appColors.primary,
                    size: 20,
                  ),
                  onTap: () {
                    if (Platform.isIOS) {
                      final isSuperuser =
                          context.read<SettingsCubit>().state.isSuperuser ??
                          false;
                      if (isSuperuser) {
                        final notLoggedIn = context
                            .read<ExchangeCubit>()
                            .state
                            .notLoggedIn;
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
                      final notLoggedIn = context
                          .read<ExchangeCubit>()
                          .state
                          .notLoggedIn;
                      if (notLoggedIn) {
                        context.goNamed(ExchangeRoute.exchangeLanding.name);
                      } else {
                        context.pushNamed(SettingsRoute.exchangeSettings.name);
                      }
                    }
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.save,
                  title: context.loc.settingsWalletBackupTitle,
                  trailing: Icon(
                    Icons.chevron_right,
                    color: context.appColors.primary,
                    size: 20,
                  ),
                  onTap: () {
                    context.pushNamed(SettingsRoute.backupSettings.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.currency_bitcoin,
                  title: context.loc.settingsBitcoinSettingsTitle,
                  trailing: Icon(
                    Icons.chevron_right,
                    color: context.appColors.primary,
                    size: 20,
                  ),
                  onTap: () {
                    context.pushNamed(SettingsRoute.bitcoinSettings.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.app_settings_alt,
                  title: context.loc.settingsAppSettingsTitle,
                  trailing: Icon(
                    Icons.chevron_right,
                    color: context.appColors.primary,
                    size: 20,
                  ),
                  onTap: () {
                    context.pushNamed(SettingsRoute.appSettings.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.description,
                  title: context.loc.settingsTermsOfServiceTitle,
                  trailing: Icon(
                    Icons.chevron_right,
                    color: context.appColors.primary,
                    size: 20,
                  ),
                  onTap: () {
                    final url = Uri.parse(
                      SettingsConstants.termsAndConditionsLink,
                    );
                    launchUrl(url, mode: LaunchMode.inAppBrowserView);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.monitor_heart,
                  iconColor: serviceStatusLoading
                      ? context.appColors.textMuted
                      : serviceStatus.allServicesOnline
                          ? context.appColors.success
                          : context.appColors.error,
                  title: context.loc.settingsServicesStatusTitle,
                  trailing: Icon(
                    Icons.chevron_right,
                    color: context.appColors.primary,
                    size: 20,
                  ),
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
        height: 120,
        padding: EdgeInsets.zero,
        color: context.appColors.transparent,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SocialButton(
                    icon: FontAwesomeIcons.telegram,
                    label: context.loc.settingsTelegramLabel,
                    url: SettingsConstants.telegramSupportLink,
                  ),
                  const Gap(32),
                  _SocialButton(
                    icon: FontAwesomeIcons.github,
                    label: context.loc.settingsGithubLabel,
                    url: SettingsConstants.githubSupportLink,
                  ),
                ],
              ),
              const Gap(16),
              if (appVersion != null)
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: appVersion));
                  },
                  child: Text(
                    'v$appVersion',
                    style: context.font.labelSmall?.copyWith(
                      color: context.appColors.textMuted.withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final uri = Uri.parse(url);
        launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: context.appColors.textMuted,
            ),
            const Gap(4),
            Text(
              label,
              style: context.font.labelSmall?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
