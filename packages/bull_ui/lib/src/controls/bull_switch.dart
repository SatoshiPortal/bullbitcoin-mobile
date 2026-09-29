import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// Switch — duplicated from `core/widgets/switch/bb_switch.dart`.
class BullSwitch extends StatelessWidget {
  const BullSwitch({super.key, required this.value, required this.onChanged});

  /// Current on/off state.
  final bool value;

  /// Fired on toggle. Null renders the switch disabled.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Switch(
      value: value,
      activeThumbColor: colors.onSecondary,
      activeTrackColor: colors.secondary,
      inactiveThumbColor: colors.border,
      inactiveTrackColor: colors.surfaceContainer,
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => colors.transparent,
      ),
      onChanged: onChanged,
    );
  }
}
