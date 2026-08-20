import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/app_language_picker.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/features/settings/ui/widgets/dev_mode_switch.dart';
import 'package:bb_mobile/features/settings/ui/widgets/error_reporting_switch.dart';
import 'package:bb_mobile/features/settings/ui/widgets/screen_capture_protection_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    final items = buildSettingsItems(
      localization: context.loc,
      exchangeTitle: context.loc.settingsExchangeSettingsTitle,
      isSuperuser: isSuperuser,
      isDevModeEnabled: isDevModeEnabled,
    );

    Widget? trailingFor(SettingsItemId id) => switch (id) {
      SettingsItemId.language => AppLanguagePicker(
        value: currentLanguage,
        onChanged: (lang) => context.read<SettingsCubit>().changeLanguage(lang),
      ),
      SettingsItemId.screenPrivacy => const ScreenCaptureProtectionSwitch(),
      SettingsItemId.devMode => const DevModeSwitch(),
      SettingsItemId.errorReporting => const ErrorReportingSwitch(),
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsAppSettingsTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final item in items.inSection(SettingsItemSection.app))
                  item.buildTile(context, trailing: trailingFor(item.id)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
