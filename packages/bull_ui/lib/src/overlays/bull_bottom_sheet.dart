import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:material_ui/material_ui.dart';

/// Modal bottom sheet.
///
/// Use [BullBottomSheet.show] to present a sheet with app-consistent chrome:
/// the themed sheet surface, borderless 8px top corners, a dark scrim
/// and the safe area.
class BullBottomSheet extends StatelessWidget {
  const BullBottomSheet({super.key, required this.child});

  /// The sheet content.
  final Widget child;

  /// Present [child] as a modal bottom sheet.
  /// With [avoidKeyboard], inset the sheet above the IME. Leave it off when
  /// [child] already consumes viewInsets to avoid adding the inset twice.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool avoidKeyboard = false,
  }) {
    final colors = context.bull;
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      useSafeArea: true,
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? colors.background
          : colors.surface,
      barrierColor: colors.scrim.withValues(
        alpha: Theme.of(context).brightness == Brightness.light ? 0.45 : 0.60,
      ),
      constraints: const BoxConstraints(minWidth: double.infinity),
      elevation: 0,
      // The sheet owns the shape and clips its content to it, so a child's
      // own decoration can never show a mismatched corner.
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.bullShapes.sheet),
        ),
        side: BorderSide.none,
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: avoidKeyboard
              ? MediaQuery.viewInsetsOf(sheetContext).bottom
              : 0,
        ),
        child: BullBottomSheet(child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => child;
}
