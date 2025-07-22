import 'dart:ui';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

/// A bottom sheet with a blurred background effect.
///
/// This widget creates a modal bottom sheet with a customizable blur effect
/// that covers the entire screen, making the content behind it slightly visible
/// but out of focus.
class BlurredBottomSheet extends StatelessWidget {
  const BlurredBottomSheet({
    super.key,
    required this.child,
    this.blurSigma = 6.0,
  });

  /// The widget to display as the content of the bottom sheet.
  final Widget child;

  /// The intensity of the blur effect. Default is 6.0.
  final double blurSigma;

  /// Shows a bottom sheet from any feature with a blurred background.
  ///
  /// This method is a convenience wrapper around [showModalBottomSheet] that
  /// pre-configures it with a [BlurredBottomSheet].
  ///
  /// Parameters:
  /// - [context]: The build context.
  /// - [isScrollControlled]: Whether the bottom sheet can be scrolled.
  /// - [blurSigma]: The intensity of the blur effect.
  /// - [child]: The content widget of the bottom sheet.
  static Future<T?> show<T>({
    required BuildContext context,
    bool isScrollControlled = true, // Default to true for better UX
    double blurSigma = 8.0,
    required Widget child,
    bool isDismissible = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      builder: (_) => BlurredBottomSheet(blurSigma: blurSigma, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand, // Fill available space
      children: [
        // Blur background
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(color: context.colour.secondary.withAlpha(25)),
          ),
        ),

        // Content
        Align(alignment: Alignment.bottomCenter, child: child),
      ],
    );
  }
}
