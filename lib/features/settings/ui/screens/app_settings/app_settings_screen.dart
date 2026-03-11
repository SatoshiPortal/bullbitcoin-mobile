import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/settings/ui/widgets/dev_mode_switch.dart';
import 'package:bb_mobile/features/settings/ui/widgets/error_reporting_switch.dart';
import 'package:bb_mobile/features/settings/ui/widgets/translation_warning_bottom_sheet.dart';
import 'package:bb_mobile/features/tor_settings/ui/tor_settings_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isSuperuser = context.select(
      (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
    );
    final currentLanguage = context.select(
      (SettingsCubit cubit) =>
          cubit.state.language ?? Language.unitedStatesEnglish,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsAppSettingsTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SettingsEntryItem(
                  icon: Icons.language,
                  title: context.loc.settingsLanguageTitle,
                  trailing: DropdownButton<Language>(
                    value: currentLanguage,
                    underline: const SizedBox.shrink(),
                    items: Language.values
                        .map(
                          (language) => DropdownMenuItem<Language>(
                            value: language,
                            child: Text(language.label),
                          ),
                        )
                        .toList(),
                    onChanged: (Language? newLanguage) {
                      if (newLanguage != null) {
                        context.read<SettingsCubit>().changeLanguage(
                          newLanguage,
                        );
                        if (newLanguage != Language.unitedStatesEnglish) {
                          TranslationWarningBottomSheet.show(context);
                        }
                      }
                    },
                  ),
                ),
                SettingsEntryItem(
                  icon: Icons.palette,
                  title: context.loc.settingsThemeTitle,
                  onTap: () {
                    context.pushNamed(SettingsRoute.theme.name);
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
                  icon: Icons.fiber_pin,
                  title: context.loc.settingsSecurityPinTitle,
                  onTap: () {
                    context.pushNamed(SettingsRoute.pinCode.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.vpn_lock,
                  title: context.loc.settingsTorSettingsTitle,
                  onTap: () {
                    context.pushNamed(TorSettingsRoute.torSettings.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.article,
                  title: context.loc.logSettingsLogsTitle,
                  onTap: () {
                    context.pushNamed(SettingsRoute.logs.name);
                  },
                ),
                if (isSuperuser)
                  SettingsEntryItem(
                    icon: Icons.logo_dev,
                    title: context.loc.appSettingsDevModeTitle,
                    trailing: const DevModeSwitch(),
                  ),
                SettingsEntryItem(
                  icon: Icons.bug_report,
                  title: context.loc.settingsErrorReportingTitle,
                  trailing: const ErrorReportingSwitch(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
