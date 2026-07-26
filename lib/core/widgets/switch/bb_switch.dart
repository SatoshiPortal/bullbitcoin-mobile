import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class BBSwitch extends StatelessWidget {
  const BBSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.materialTapTargetSize,
  });

  final bool value;

  /// Null renders the switch disabled.
  final ValueChanged<bool>? onChanged;

  /// Pass [MaterialTapTargetSize.shrinkWrap] for dense placements (e.g.
  /// single-line tiles).
  final MaterialTapTargetSize? materialTapTargetSize;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      materialTapTargetSize: materialTapTargetSize,
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
