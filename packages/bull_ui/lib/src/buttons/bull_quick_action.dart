import 'dart:async';

import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

/// A compact, accessible shortcut at a stable height across text scales: a
/// round icon disc over a one-line label on its own, or icon over label with
/// no disc as one cell of a [BullQuickActionBar].
class BullQuickAction extends StatelessWidget {
  const BullQuickAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.onLongPress,
    this.semanticLabel,
    this.outlined = false,
    this.disabled = false,
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
            height: flat ? BullQuickActionBar.height : height,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: BullSpacing.xxs,
                      vertical: BullSpacing.xxs,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (flat)
                          BullIcon(icon, size: 26, color: foreground)
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
                              child: BullIcon(
                                icon,
                                size: 24,
                                color: foreground,
                              ),
                            ),
                          ),
                        const SizedBox(height: BullSpacing.xs),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style:
                              (flat
                                      ? Theme.of(context).textTheme.labelLarge
                                      : Theme.of(context).textTheme.titleMedium)
                                  ?.copyWith(
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
/// with no disc: the strip that straddles the bottom edge of a hero.
class BullQuickActionBar extends StatelessWidget {
  const BullQuickActionBar({super.key, required this.children});

  /// The actions, left to right.
  final List<Widget> children;

  /// Height of the card.
  static const double height = 88;

  /// Whether [context] sits inside a [BullQuickActionBar].
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BullQuickActionBarScope>() !=
      null;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final radius = BorderRadius.circular(context.bullShapes.card);
    return _BullQuickActionBarScope(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: colors.scrim,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: colors.onSecondary,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: colors.outlineVariant),
          ),
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                for (final (index, child) in children.indexed) ...[
                  if (index > 0)
                    Container(width: 1, color: colors.outlineVariant),
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

/// A row of up to four [BullQuickAction]s sharing the width equally, at
/// [BullQuickAction.height]: Home's and the exchange's shortcut strip.
class BullQuickActionRow extends StatelessWidget {
  const BullQuickActionRow({super.key, required this.children});

  /// The actions, left to right.
  final List<Widget> children;

  /// Gap between two cells.
  static const double spacing = BullSpacing.xs;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: BullQuickAction.height,
    child: Row(
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) const SizedBox(width: spacing),
          Expanded(child: child),
        ],
      ],
    ),
  );
}

/// [BullQuickAction]s wrapped into rows of [columns] cells as wide as one
/// [BullQuickActionRow] cell: the More sheet and the editor.
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

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width =
          (constraints.maxWidth - BullQuickActionRow.spacing * (columns - 1)) /
          columns;
      return Wrap(
        spacing: BullQuickActionRow.spacing,
        runSpacing: BullQuickActionRow.spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
