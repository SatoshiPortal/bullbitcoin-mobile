import 'package:preferences/preferences.dart';
import 'package:settings/src/presentation/bloc/settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart' show BullSwitch;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// Shows the theme in use, so a stored "system" preference reads as whatever
/// the device currently applies; any toggle stores an explicit choice.
class DarkModeSwitch extends StatelessWidget {
  const DarkModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return BullSwitch(
      value: Theme.of(context).brightness == Brightness.dark,
      onChanged: (dark) => context.read<SettingsCubit>().changeThemeMode(
        dark ? AppThemeMode.dark : AppThemeMode.light,
      ),
    );
  }
}
