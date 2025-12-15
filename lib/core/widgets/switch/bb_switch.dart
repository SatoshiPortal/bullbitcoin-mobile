import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class BBSwitch extends StatelessWidget {
  const BBSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      activeThumbColor: context.appColors.onSecondary,
      activeTrackColor: context.appColors.secondary,
      inactiveThumbColor: context.appColors.border,
      inactiveTrackColor: context.appColors.surfaceContainer,
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) => context.appColors.transparent,
      ),
      onChanged: onChanged,
    );
  }
}
