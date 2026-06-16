import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';

/// Modal bottom sheet — duplicated from `core/widgets/bottom_sheet/x.dart`.
///
/// Use [BullBottomSheet.show] to present a sheet with app-consistent chrome
/// (16px top corners per the design, scrim, safe area).
class BullBottomSheet extends StatelessWidget {
  const BullBottomSheet({super.key, required this.child});

  /// The sheet content.
  final Widget child;

  /// Present [child] as a modal bottom sheet.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = true,
    bool isDismissible = true,
  }) {
    final colors = context.bull;
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      useSafeArea: true,
      backgroundColor: colors.surface,
      barrierColor: colors.text.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BullRadius.lg),
        ),
      ),
      builder: (_) => BullBottomSheet(child: child),
    );
  }

  @override
  Widget build(BuildContext context) => child;
}
