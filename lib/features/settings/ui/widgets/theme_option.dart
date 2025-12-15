import 'package:bb_mobile/core_deprecated/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ThemeOption extends StatelessWidget {
  const ThemeOption({super.key, required this.themeMode});

  final AppThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      tileColor: context.appColors.transparent,
      selected:
          context.watch<SettingsCubit>().state.storedSettings?.themeMode ==
          themeMode,
      title: Text(_getThemeDisplayName(themeMode)),
      subtitle: Text(_getThemeDescription(themeMode)),
      onTap: () {
        context.read<SettingsCubit>().changeThemeMode(themeMode);
      },
    );
  }

  String _getThemeDisplayName(AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System';
    }
  }

  String _getThemeDescription(AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        return 'Use light theme';
      case AppThemeMode.dark:
        return 'Use dark theme';
      case AppThemeMode.system:
        return 'Follow system setting';
    }
  }
}
