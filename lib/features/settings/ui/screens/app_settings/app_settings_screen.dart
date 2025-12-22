import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/settings/ui/widgets/dev_mode_switch.dart';
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
                  icon: Icons.article,
                  title: context.loc.logSettingsLogsTitle,
                  onTap: () {
                    context.pushNamed(SettingsRoute.logs.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.security,
                  title: context.loc.settingsTorSettingsTitle,
                  onTap: () {
                    context.pushNamed(TorSettingsRoute.torSettings.name);
                  },
                ),
                if (isSuperuser)
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
                        }
                      },
                    ),
                  ),
                if (isSuperuser)
                  SettingsEntryItem(
                    icon: Icons.developer_mode,
                    title: context.loc.appSettingsDevModeTitle,
                    trailing: const DevModeSwitch(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
