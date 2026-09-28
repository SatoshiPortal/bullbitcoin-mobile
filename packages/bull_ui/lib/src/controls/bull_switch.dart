import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// Themed on/off switch.
///
/// Matches the app-wide switch theme: a surface-coloured thumb on a [text]
/// track when on and a [textMuted] track when off, so the off track stays
/// visible on both plain and tinted rows.
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
      inactiveThumbColor: colors.surface,
      inactiveTrackColor: colors.textMuted,
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => colors.transparent,
      ),
      onChanged: onChanged,
    );
  }
}
