import 'package:bb_mobile/core_deprecated/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/widgets/theme_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SettingsCubit, SettingsState>(
      listenWhen:
          (previous, current) =>
              current.storedSettings?.themeMode !=
              previous.storedSettings?.themeMode,
      listener: (context, state) => context.pop(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Theme')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children:
                AppThemeMode.values
                    .map((themeMode) => ThemeOption(themeMode: themeMode))
                    .toList(),
          ),
        ),
      ),
    );
  }
}
