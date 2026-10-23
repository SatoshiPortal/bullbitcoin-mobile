import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
      title: Text(_getThemeDisplayName(context, themeMode)),
      subtitle: Text(_getThemeDescription(context, themeMode)),
      onTap: () {
        context.read<SettingsCubit>().changeThemeMode(themeMode);
      },
    );
  }

  String _getThemeDisplayName(BuildContext context, AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        return context.loc.themeLight;
      case AppThemeMode.dark:
        return context.loc.themeDark;
      case AppThemeMode.system:
        return context.loc.themeSystem;
    }
  }

  String _getThemeDescription(BuildContext context, AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        return context.loc.themeLightDescription;
      case AppThemeMode.dark:
        return context.loc.themeDarkDescription;
      case AppThemeMode.system:
        return context.loc.themeSystemDescription;
    }
  }
}
