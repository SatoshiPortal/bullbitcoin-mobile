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
      activeThumbColor: colors.surface,
      activeTrackColor: colors.text,
      inactiveThumbColor: colors.muted,
      inactiveTrackColor: colors.outlineVariant,
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => Colors.transparent,
      ),
      onChanged: onChanged,
    );
  }
}
