import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:material_ui/material_ui.dart';

class EyeToggle extends StatelessWidget {
  final bool? hideAmounts;
  final String showLabel;
  final String hideLabel;
  final ValueChanged<bool> onChanged;

  const EyeToggle({
    super.key,
    required this.hideAmounts,
    required this.showLabel,
    required this.hideLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hide = hideAmounts ?? true;
    return IconButton(
      tooltip: hide ? showLabel : hideLabel,
      // 9 + 30 + 9 keeps a 48 dp target around the unchanged 30 dp badge.
      padding: const EdgeInsets.all(9),
      onPressed: () => onChanged(!hide),
      icon: Container(
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
