import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Themed on/off switch.
///
/// Off reads as off at a glance: a hollow track ringed in [BullTheme.outline]
/// around a grey thumb carrying a cross. On fills the track with
/// [BullTheme.primary] around a white thumb carrying a check. The app's
/// `SwitchThemeData` is [themeData], so every Material [Switch] looks alike.
class BullSwitch extends StatelessWidget {
  const BullSwitch({super.key, required this.value, required this.onChanged});

  /// Current on/off state.
  final bool value;

  /// Fired on toggle. Null renders the switch disabled.
  final ValueChanged<bool>? onChanged;

  /// The switch look for [colors], for a `ThemeData.switchTheme` as well as
  /// for [BullSwitch] itself. A disabled switch keeps the look, faded.
  static SwitchThemeData themeData(BullTheme colors) {
    Color faded(Set<WidgetState> states, Color color) =>
        states.contains(WidgetState.disabled)
        ? color.withValues(alpha: 0.38)
        : color;
    bool on(Set<WidgetState> states) => states.contains(WidgetState.selected);
    return SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            faded(states, on(states) ? colors.primary : colors.transparent),
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => faded(states, on(states) ? colors.primary : colors.outline),
      ),
      trackOutlineWidth: const WidgetStatePropertyAll(2),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            faded(states, on(states) ? colors.onPrimary : colors.textMuted),
      ),
      thumbIcon: WidgetStateProperty.resolveWith(
        (states) => on(states)
            ? Icon(Icons.check, color: faded(states, colors.primary))
            : Icon(Icons.close, color: faded(states, colors.background)),
      ),
      padding: EdgeInsets.zero,
      overlayColor: WidgetStatePropertyAll(colors.transparent),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      splashRadius: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SwitchTheme(
      data: themeData(context.bull),
      child: Switch(value: value, onChanged: onChanged),
    );
  }
}
