import 'package:bull_ui/bull_ui.dart';
import 'with_bull_theme.dart';

class DialPad extends StatelessWidget {
  final ValueChanged<String> onNumberPressed;
  final VoidCallback onBackspacePressed;
  final bool disableFeedback;
  final bool onlyDigits;

  DialPad({
    super.key,
    ValueChanged<String>? onDigit,
    VoidCallback? onBackspace,
    ValueChanged<String>? onNumberPressed,
    VoidCallback? onBackspacePressed,
    this.disableFeedback = false,
    this.onlyDigits = false,
  }) : onNumberPressed = onNumberPressed ?? onDigit!,
       onBackspacePressed = onBackspacePressed ?? onBackspace!;

  @override
  Widget build(BuildContext context) => withBullTheme(
    context,
    BullDialPad(
      onNumberPressed: onNumberPressed,
      onBackspacePressed: onBackspacePressed,
      disableFeedback: disableFeedback,
      onlyDigits: onlyDigits,
    ),
  );
}
