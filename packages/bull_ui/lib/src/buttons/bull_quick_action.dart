import 'dart:async';

import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

/// The backdrop a [BullQuickAction] is drawn on, which picks its palette.
enum BullQuickActionTone {
  /// A themed surface: the icon disc is [BullTheme.surfaceContainerHighest]
  /// and the label [BullTheme.text].
  surface,

  /// A dark hero that stays dark in both themes: a translucent
  /// [BullTheme.onPrimary] disc and label, the same in light and dark mode.
  inverse,
}

/// A compact, accessible shortcut: a round icon disc over a one-line label,
/// with no box around it, at a stable height across text scales.
class BullQuickAction extends StatelessWidget {
  const BullQuickAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.onLongPress,
    this.semanticLabel,
    this.outlined = false,
    this.disabled = false,
    this.tone = BullQuickActionTone.surface,
    super.key,
  });

  static const double height = 108;

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

  /// The backdrop this action sits on.
  final BullQuickActionTone tone;

  void _activate(VoidCallback callback) {
    unawaited(HapticFeedback.selectionClick());
    callback();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final inverse = tone == BullQuickActionTone.inverse;
    final foreground = inverse ? colors.onPrimary : colors.text;
    final fill = inverse
        ? colors.onPrimary.withValues(alpha: 0.18)
        : colors.surfaceContainerHighest;
    final ring = inverse
        ? colors.onPrimary.withValues(alpha: 0.5)
        : colors.border;
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
            height: height,
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
                            child: BullIcon(icon, size: 24, color: foreground),
                          ),
                        ),
                        const SizedBox(height: BullSpacing.xs),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall
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
