import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Underlined navigation reserved for advanced options.
class BullAdvancedOptionsLink extends StatelessWidget {
  const BullAdvancedOptionsLink({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: context.bull.primary,
      disabledForegroundColor: context.bull.primary.withValues(alpha: 0.5),
      minimumSize: const Size(48, 48),
      tapTargetSize: MaterialTapTargetSize.padded,
      textStyle: context.bullType.body.copyWith(
        decoration: TextDecoration.underline,
      ),
    ),
    child: Text(label),
  );
}
