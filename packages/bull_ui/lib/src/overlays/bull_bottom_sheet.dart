import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';

/// Modal bottom sheet.
///
/// Use [BullBottomSheet.show] to present a sheet with app-consistent chrome:
/// the app background, 8px top corners with a hairline border, a light scrim
/// and the safe area.
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
      backgroundColor: colors.background,
      barrierColor: colors.surface.withAlpha(100),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(BullRadius.sm),
        ),
        side: BorderSide(color: colors.secondaryFixedDim),
      ),
      builder: (_) => BullBottomSheet(child: child),
    );
  }

  @override
  Widget build(BuildContext context) => child;
}
