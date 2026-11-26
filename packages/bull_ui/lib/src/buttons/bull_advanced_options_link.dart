import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Underlined navigation reserved for advanced options.
class BullAdvancedOptionsLink extends StatelessWidget {
  const BullAdvancedOptionsLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.bold = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Text colour; defaults to `context.bull.primary`.
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? context.bull.primary;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        disabledForegroundColor: foreground.withValues(alpha: 0.5),
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: context.bullType.body.copyWith(
          decoration: TextDecoration.underline,
          fontWeight: bold ? FontWeight.w700 : null,
        ),
      ),
      child: Text(label),
    );
  }
}
