import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/app_language_picker.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/settings/ui/widgets/dev_mode_switch.dart';
import 'package:bb_mobile/features/settings/ui/widgets/error_reporting_switch.dart';
import 'package:bb_mobile/features/settings/ui/widgets/exchange_testnet_basic_auth_tile.dart';
import 'package:bb_mobile/features/tor_settings/ui/tor_settings_router.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isSuperuser = context.select(
      (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
    );
    final isDevModeEnabled = context.select(
      (SettingsCubit cubit) => cubit.state.isDevModeEnabled ?? false,
    );
    final currentLanguage = context.select(
      (SettingsCubit cubit) =>
          cubit.state.language ?? Language.unitedStatesEnglish,
    );

    return BullPage(
      topBar: BullTopBar(
        title: context.loc.settingsAppSettingsTitle,
        onBack: context.pop,
      ),
      padding: const EdgeInsets.symmetric(horizontal: BullSpacing.md),
      scrollable: true,
      child: Column(
        children: [
          BullSettingsEntryItem(
            icon: Icons.language,
            title: context.loc.settingsLanguageTitle,
            trailing: AppLanguagePicker(
              value: currentLanguage,
              onChanged: (lang) =>
                  context.read<SettingsCubit>().changeLanguage(lang),
            ),
          ),
          BullSettingsEntryItem(
            icon: Icons.palette,
            title: context.loc.settingsThemeTitle,
            onTap: () {
              context.pushNamed(SettingsRoute.theme.name);
            },
          ),
          BullSettingsEntryItem(
            icon: Icons.attach_money,
            title: context.loc.settingsCurrencyTitle,
            onTap: () {
              context.pushNamed(SettingsRoute.currency.name);
            },
          ),
          BullSettingsEntryItem(
            icon: Icons.fiber_pin,
            title: context.loc.settingsSecurityPinTitle,
            onTap: () {
              context.pushNamed(SettingsRoute.pinCode.name);
            },
          ),
          BullSettingsEntryItem(
            icon: Icons.vpn_lock,
            title: context.loc.settingsTorSettingsTitle,
            onTap: () {
              context.pushNamed(TorSettingsRoute.torSettings.name);
            },
          ),
          BullSettingsEntryItem(
            icon: Icons.article,
            title: context.loc.logSettingsLogsTitle,
            onTap: () {
              context.pushNamed(SettingsRoute.logs.name);
            },
          ),
          if (isSuperuser)
            BullSettingsEntryItem(
              icon: Icons.logo_dev,
              title: context.loc.appSettingsDevModeTitle,
              trailing: const DevModeSwitch(),
            ),
          if (isDevModeEnabled) const ExchangeTestnetBasicAuthTile(),
          BullSettingsEntryItem(
            icon: Icons.bug_report,
            title: context.loc.settingsErrorReportingTitle,
            trailing: const ErrorReportingSwitch(),
          ),
        ],
      ),
    );
  }
}
