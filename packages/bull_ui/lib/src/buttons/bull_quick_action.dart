import 'package:bull_ui/src/theme/bull_typography.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

/// A compact, accessible shortcut: a round icon disc over a one-line label on
/// its own, or icon over label with no disc as one cell of a
/// [BullQuickActionBar].
class BullQuickAction extends StatelessWidget {
  const BullQuickAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.onLongPress,
    this.semanticLabel,
    this.outlined = false,
    this.disabled = false,
    this.badgeCount = 0,
    super.key,
  });

  static const double height = 116;

  /// Diameter of the icon disc.
  static const double _disc = 52;

  final String label;
  final String? semanticLabel;
  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  /// A hollow disc with a ring instead of a fill: the More cell.
  final bool outlined;
  final bool disabled;

  /// A count shown on the icon. Nothing is shown at zero.
  final int badgeCount;

  Widget _badged(BuildContext context, Widget child) => Badge(
    isLabelVisible: badgeCount > 0,
    label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
    backgroundColor: context.bull.error,
    textColor: context.bull.onError,
    child: child,
  );

  void _activate(VoidCallback callback) {
    unawaited(HapticFeedback.selectionClick());
    callback();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final flat = BullQuickActionBar.of(context);
    final foreground = colors.text;
    final fill = colors.surfaceContainerHighest;
    final ring = colors.border;
    final tap = disabled ? null : () => _activate(onPressed);
    final longPressCallback = onLongPress;
    final longPress = disabled || longPressCallback == null
        ? null
        : () => _activate(longPressCallback);
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      enabled: !disabled,
      onTap: tap,
      onLongPress: longPress,
      child: ExcludeSemantics(
        child: Tooltip(
          message: semanticLabel ?? label,
          excludeFromSemantics: true,
          triggerMode: longPress == null
              ? TooltipTriggerMode.longPress
              : TooltipTriggerMode.manual,
          child: SizedBox(
            height: flat ? null : height,
            child: Opacity(
              opacity: disabled ? 0.4 : 1,
              child: Material(
                color: colors.transparent,
                borderRadius: BorderRadius.circular(context.bullShapes.button),
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    context.bullShapes.button,
                  ),
                  splashColor: foreground.withValues(alpha: 0.08),
                  highlightColor: foreground.withValues(alpha: 0.04),
                  onTap: tap,
                  onLongPress: longPress,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: BullSpacing.xxs,
                      vertical: flat
                          ? BullQuickActionBar._verticalPadding
                          : BullSpacing.xxs,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (flat)
                          _badged(
                            context,
                            BullIcon(
                              icon,
                              size: BullQuickActionBar._iconSize,
                              color: foreground,
                            ),
                          )
                        else
                          Container(
                            width: _disc,
                            height: _disc,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: outlined ? colors.transparent : fill,
                              border: outlined
                                  ? Border.all(color: ring, width: 1.5)
                                  : null,
                            ),
                            child: Center(
                              child: _badged(
                                context,
                                BullIcon(icon, size: 24, color: foreground),
                              ),
                            ),
                          ),
                        SizedBox(
                          height: flat
                              ? BullQuickActionBar._labelGap
                              : BullSpacing.xs,
                        ),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style:
                              (flat
                                      ? BullQuickActionBar._labelStyle(context)
                                      : context.bullType.body.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ))
                                  .copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: foreground,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A card of [BullQuickAction]s split by hairline dividers, icon over label
/// with no disc: the strip that straddles the bottom edge of a hero. White on
/// the light palette ([BullTheme.surface]), black on the dark one
/// ([BullTheme.background]).
class BullQuickActionBar extends StatelessWidget {
  const BullQuickActionBar({super.key, required this.children});

  /// The actions, left to right.
  final List<Widget> children;

  /// Minimum height of the card.
  static const double minHeight = BullSizes.homeCard;

  /// Padding above the icon and below the label.
  static const double _verticalPadding = BullSpacing.xs;

  static const double _iconSize = 24;

  static const double _labelGap = BullSpacing.xxs;

  static TextStyle _labelStyle(BuildContext context) =>
      context.bullType.label.copyWith(fontWeight: FontWeight.w600);

  /// [minHeight], or taller when a large text scale needs room for the label.
  static double heightOf(BuildContext context) {
    if (_labelStyle(context) case TextStyle(:final fontSize?, :final height?)) {
      final label = MediaQuery.textScalerOf(context).scale(fontSize) * height;
      final content = 2 * _verticalPadding + _iconSize + _labelGap + label;
      return math.max(content, minHeight);
    }
    return minHeight;
  }

  /// Whether [context] sits inside a [BullQuickActionBar].
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BullQuickActionBarScope>() !=
      null;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final radius = BorderRadius.circular(context.bullShapes.card);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _BullQuickActionBarScope(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          // A dark shadow is invisible on the black dark-theme page, so the
          // bar lifts off it with a faint light glow instead.
          boxShadow: [
            BoxShadow(
              color: dark
                  ? colors.onSurface.withValues(alpha: 0.12)
                  : colors.scrim,
              blurRadius: 12,
              offset: dark ? Offset.zero : const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: dark ? colors.background : colors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: radius),
          child: SizedBox(
            height: heightOf(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, child) in children.indexed) ...[
                  if (index > 0)
                    Container(
                      width: 1,
                      color: dark ? colors.surface : colors.outlineVariant,
                    ),
                  Expanded(child: child),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BullQuickActionBarScope extends InheritedWidget {
  const _BullQuickActionBarScope({required super.child});

  @override
  bool updateShouldNotify(_BullQuickActionBarScope oldWidget) => false;
}

/// [BullQuickAction]s wrapped into rows of [columns] equal cells: the More
/// sheet and the editor.
class BullQuickActionGrid extends StatelessWidget {
  const BullQuickActionGrid({
    super.key,
    required this.children,
    this.columns = 4,
  });

  /// The actions, in reading order.
  final List<Widget> children;

  /// Cells per row.
  final int columns;

  /// Gap between two cells.
  static const double spacing = BullSpacing.xs;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
