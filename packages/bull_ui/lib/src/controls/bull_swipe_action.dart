import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';

/// Swipe-to-reveal-one-action row. **New (key gap)** — no equivalent exists in
/// `lib/core/widgets`.
///
/// Dragging [child] to the left reveals a single coloured action panel
/// ([actionColor] with [actionIcon] + [actionLabel] in [actionForeground]). The
/// action **commits** — firing [onAction] — when the drag passes 60% of the
/// reveal width or on a full swipe; otherwise the row snaps back. Tapping the
/// revealed panel also fires. When [enabled] is false the gesture is inert (e.g.
/// while a list is in selection mode).
class BullSwipeAction extends StatefulWidget {
  const BullSwipeAction({
    super.key,
    required this.child,
    required this.actionLabel,
    required this.actionIcon,
    required this.actionColor,
    required this.onAction,
    this.actionForeground,
    this.enabled = true,
    this.revealWidth = 92,
  });

  /// The row content.
  final Widget child;

  /// Action label shown in the revealed panel.
  final String actionLabel;

  /// Action icon shown in the revealed panel.
  final IconData actionIcon;

  /// Solid colour of the revealed action panel.
  final Color actionColor;

  /// Icon and label colour on the [actionColor] panel. Defaults to the theme's
  /// on-red foreground (a high-contrast light colour in both brightnesses).
  final Color? actionForeground;

  /// Fired when the action commits.
  final VoidCallback onAction;

  /// When false, the swipe gesture is disabled.
  final bool enabled;

  /// Width of the revealed action panel (px).
  final double revealWidth;

  @override
  State<BullSwipeAction> createState() => _BullSwipeActionState();
}

class _BullSwipeActionState extends State<BullSwipeAction> {
  /// Current horizontal offset of the child (0 = closed, negative = open left).
  double _dx = 0;
  bool _animating = false;

  /// Fraction of the reveal width past which the action commits.
  static const double _commitFraction = 0.6;

  void _onDragUpdate(DragUpdateDetails d) {
    if (!widget.enabled) return;
    setState(() {
      _dx = (_dx + d.delta.dx).clamp(-widget.revealWidth, 0.0);
    });
  }

  void _onDragEnd(DragEndDetails d) {
    if (!widget.enabled) return;
    final dragged = -_dx;
    final committed = dragged >= widget.revealWidth * _commitFraction;
    if (committed) {
      _fire();
    } else {
      _close();
    }
  }

  void _fire() {
    setState(() {
      _dx = 0;
      _animating = true;
    });
    widget.onAction();
  }

  void _close() => setState(() {
    _dx = 0;
    _animating = true;
  });

  @override
  Widget build(BuildContext context) {
    final foreground = widget.actionForeground ?? context.bull.onPrimary;
    return ClipRect(
      child: Stack(
        children: [
          // Action panel behind the child, revealed on the trailing edge.
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                button: true,
                label: widget.actionLabel,
                child: GestureDetector(
                  onTap: widget.enabled && _dx < 0 ? _fire : null,
                  child: Container(
                    width: widget.revealWidth,
                    color: widget.actionColor,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: BullSpacing.xs,
                    ),
                    // OverflowBox gives the icon+label column unbounded height so
                    // it lays out at its natural size and centres in the panel —
                    // never asserting an overflow, however short the row is
                    // (ClipRect at the root trims any excess on a tiny row).
                    child: OverflowBox(
                      minHeight: 0,
                      maxHeight: double.infinity,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          BullIcon(
                            widget.actionIcon,
                            size: 22,
                            color: foreground,
                          ),
                          const SizedBox(height: BullSpacing.xxs),
                          Text(
                            widget.actionLabel,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontSize: 11,
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
          GestureDetector(
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: AnimatedContainer(
              duration: _animating
                  ? const Duration(milliseconds: 180)
                  : Duration.zero,
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(_dx, 0, 0),
              onEnd: () => _animating = false,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
