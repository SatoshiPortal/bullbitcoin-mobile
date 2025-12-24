import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

/// A bottom sheet with a blurred background effect.
///
/// This widget creates a modal bottom sheet with a customizable blur effect
/// that covers the entire screen, making the content behind it slightly visible
/// but out of focus.
class BlurredBottomSheet extends StatelessWidget {
  const BlurredBottomSheet({super.key, required this.child});

  /// The widget to display as the content of the bottom sheet.
  final Widget child;

  /// Parameters:
  /// - [context]: The build context.
  /// - [isScrollControlled]: Whether the bottom sheet can be scrolled.
  /// - [child]: The content widget of the bottom sheet.
  static Future<T?> show<T>({
    required BuildContext context,
    bool isScrollControlled = true, // Default to true for better UX
    required Widget child,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      useSafeArea: true,
      backgroundColor: context.appColors.background,
      barrierColor: context.appColors.surface.withAlpha(100),
      builder: (_) => BlurredBottomSheet(child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
