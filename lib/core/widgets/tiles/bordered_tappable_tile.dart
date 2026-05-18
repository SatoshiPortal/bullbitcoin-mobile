import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

/// Bordered surface used across the receive / send / labels flows.
///
/// Visual: rounded rectangle with [AppColors.onSecondary] background,
/// 8px radius, and [AppColors.secondaryFixedDim] border.
///
/// When [onTap] or [onLongPress] is provided, the whole surface shows an
/// [InkWell] ripple and triggers the matching callback. When both are null,
/// the tile is purely visual and any nested interactive widgets (e.g. an
/// `AddressViewer` with its own gesture handling) keep ownership of
/// gestures.
class BorderedTappableTile extends StatelessWidget {
  const BorderedTappableTile({
    super.key,
    this.onTap,
    this.onLongPress,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
    this.backgroundColor,
  });

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Override the surface fill. Defaults to [AppColors.onSecondary] (the
  /// editable / interactive variant). Pass [AppColors.surfaceContainerHighest]
  /// for a read-only display panel that still accepts taps (e.g. the receive
  /// address tile that opens a detail dialog but can't be edited) — the
  /// recessed tint signals "passive display" while keeping tap behaviour.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: backgroundColor ?? context.appColors.onSecondary,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.appColors.secondaryFixedDim),
    );
    final body = Padding(padding: padding, child: child);

    if (onTap == null && onLongPress == null) {
      return DecoratedBox(decoration: decoration, child: body);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Ink(decoration: decoration, child: body),
      ),
    );
  }
}
