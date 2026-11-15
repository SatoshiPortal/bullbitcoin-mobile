import 'package:bull_ui/bull_ui.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EyeToggle extends StatelessWidget {
  const EyeToggle();

  @override
  Widget build(BuildContext context) {
    final hide = context.select(
      (SettingsCubit settingsCubit) => settingsCubit.state.hideAmounts ?? true,
    );
    return GestureDetector(
      onTap: () {
        context.read<SettingsCubit>().toggleHideAmounts(!hide);
      },
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.bullShapes.key),
          border: Border.all(color: context.appColors.surfaceBright),
          color: context.appColors.scrim,
        ),
        child: Icon(
          !hide ? Icons.visibility : Icons.visibility_off,
          color: context.appColors.onPrimary,
          size: 20,
        ),
      ),
    );
  }
}
