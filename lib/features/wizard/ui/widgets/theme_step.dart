import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

class ThemeStep extends StatelessWidget {
  const ThemeStep({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final AppThemeMode selected;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AppThemeMode>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: AppThemeMode.light,
          label: Text(context.loc.themeLight),
        ),
        ButtonSegment(
          value: AppThemeMode.dark,
          label: Text(context.loc.themeDark),
        ),
        ButtonSegment(
          value: AppThemeMode.system,
          label: Text(context.loc.themeSystem),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
