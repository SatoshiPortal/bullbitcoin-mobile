import '../theme/bull_tokens.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// Bordered surface used across receive / send / labels flows — duplicated
/// from `core/widgets/tiles/bordered_tappable_tile.dart`
/// (`BorderedTappableTile`).
///
/// Rounded rectangle with an [BullTheme.onSecondary] background, 8px radius and
/// a [BullTheme.secondaryFixedDim] border. When [onTap]/[onLongPress] is set
/// the whole surface shows an ink ripple; otherwise it is purely visual and
/// nested interactive children keep gesture ownership.
class BullBorderedTile extends StatelessWidget {
  const BullBorderedTile({
    super.key,
    this.onTap,
    this.onLongPress,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.backgroundColor,
  });

  /// Tap callback.
  final VoidCallback? onTap;

  /// Long-press callback.
  final VoidCallback? onLongPress;

  /// Tile content.
  final Widget child;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Override the surface fill; defaults to [BullTheme.onSecondary].
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final decoration = BoxDecoration(
      color: backgroundColor ?? colors.onSecondary,
      borderRadius: BorderRadius.circular(BullRadius.xxs),
      border: Border.all(color: colors.secondaryFixedDim),
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
        borderRadius: BorderRadius.circular(BullRadius.xxs),
        child: Ink(decoration: decoration, child: body),
      ),
    );
  }
}
