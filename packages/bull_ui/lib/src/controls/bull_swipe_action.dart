import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';

/// Swipe-to-reveal-action row. **New (key gap)** — no equivalent exists in
/// `lib/core/widgets`.
///
/// Dragging [child] to the left reveals a coloured trailing action panel
/// ([actionColor] with [actionIcon] + [actionLabel] in [actionForeground]).
/// Dragging it to the right reveals an optional **leading** action, configured
/// through [onLeadingAction] and its `leading*` siblings; without that callback
/// the row does not move rightwards at all.
///
/// An action **commits** — firing its callback — when the drag passes 60% of the
/// reveal width on that side; otherwise the row snaps back. Tapping a revealed
/// panel also fires. When [enabled] is false both gestures are inert (e.g. while
/// a list is in selection mode).
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
    this.onLeadingAction,
    this.leadingActionLabel,
    this.leadingActionIcon,
    this.leadingActionColor,
    this.leadingActionForeground,
  }) : assert(
         onLeadingAction == null ||
             (leadingActionLabel != null &&
                 leadingActionIcon != null &&
                 leadingActionColor != null),
         'a leading action needs its label, icon and colour',
       );

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

  /// Width of the revealed action panel (px). Shared by both sides.
  final double revealWidth;

  /// Fired when the leading (swipe-right) action commits. Null disables the
  /// rightward gesture entirely.
  final VoidCallback? onLeadingAction;

  /// Label of the leading action panel. Required with [onLeadingAction].
  final String? leadingActionLabel;

  /// Icon of the leading action panel. Required with [onLeadingAction].
  final IconData? leadingActionIcon;

  /// Solid colour of the leading action panel. Required with [onLeadingAction].
  final Color? leadingActionColor;

  /// Icon and label colour on the leading panel.
  final Color? leadingActionForeground;

  @override
  State<BullSwipeAction> createState() => _BullSwipeActionState();
}

class _BullSwipeActionState extends State<BullSwipeAction> {
  /// Current horizontal offset of the child (0 = closed, negative = open left).
  double _dx = 0;
  bool _animating = false;

  /// Which side is revealed: -1 trailing, +1 leading, 0 none. Survives the close
  /// animation so the right panel keeps painting while sliding shut — and, just
  /// as importantly, so the *other* panel never paints at the same time.
  int _side = 0;

  /// Fraction of the reveal width past which the action commits.
  static const double _commitFraction = 0.6;

  @override
  void didUpdateWidget(BullSwipeAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the gesture is disabled (e.g. the list enters selection mode after a
    // long-press), snap the row closed so a partially-revealed action panel
    // can't linger over the row content.
    if (oldWidget.enabled && !widget.enabled && _dx != 0) {
      setState(() {
        _dx = 0;
        _animating = true;
      });
    }
  }

  /// How far the row may travel rightwards — zero without a leading action, so
  /// the gesture stays exactly as it was for callers that don't opt in.
  double get _maxLeading =>
      widget.onLeadingAction == null ? 0.0 : widget.revealWidth;

  void _onDragUpdate(DragUpdateDetails d) {
    if (!widget.enabled) return;
    setState(() {
      _dx = (_dx + d.delta.dx).clamp(-widget.revealWidth, _maxLeading);
      // Keep the previous side while exactly closed, so a drag through zero
      // doesn't flicker the panel it is leaving.
      if (_dx < 0) {
        _side = -1;
      } else if (_dx > 0) {
        _side = 1;
      }
    });
  }

  void _onDragEnd(DragEndDetails d) {
    if (!widget.enabled) return;
    final threshold = widget.revealWidth * _commitFraction;
    if (_dx <= -threshold) {
      _fire();
    } else if (_dx >= threshold && widget.onLeadingAction != null) {
      _fireLeading();
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

  void _fireLeading() {
    setState(() {
      _dx = 0;
      _animating = true;
    });
    widget.onLeadingAction!.call();
  }

  void _close() => setState(() {
    _dx = 0;
    _animating = true;
  });

  @override
  Widget build(BuildContext context) {
    final foreground = widget.actionForeground ?? context.bull.onPrimary;
    // A panel only exists while its own side is open or animating closed; a
    // closed row has nothing to reveal. Painting one unconditionally let it show
    // through a translucent row above (e.g. a selected tile's tinted
    // background), and would paint both panels at once now that there are two.
    final revealing = _dx != 0 || _animating;
    final revealingTrailing = revealing && _side < 0;
    final revealingLeading = revealing && _side > 0;
    return ClipRect(
      child: Stack(
        children: [
          // Leading panel, revealed by dragging rightwards.
          if (revealingLeading && widget.onLeadingAction != null)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label: widget.leadingActionLabel,
                  child: GestureDetector(
                    onTap: widget.enabled ? _fireLeading : null,
                    child: _ActionPanel(
                      width: widget.revealWidth,
                      color: widget.leadingActionColor!,
                      icon: widget.leadingActionIcon!,
                      label: widget.leadingActionLabel!,
                      foreground:
                          widget.leadingActionForeground ??
                          context.bull.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          // Action panel behind the child, revealed on the trailing edge.
          if (revealingTrailing)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  button: true,
                  label: widget.actionLabel,
                  child: GestureDetector(
                    onTap: widget.enabled && _dx < 0 ? _fire : null,
                    child: _ActionPanel(
                      width: widget.revealWidth,
                      color: widget.actionColor,
                      icon: widget.actionIcon,
                      label: widget.actionLabel,
                      foreground: foreground,
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
              // Drop the panel once the close animation lands so it stops being
              // painted behind the at-rest row.
              onEnd: () {
                if (mounted && _animating) {
                  setState(() {
                    _animating = false;
                    _side = 0;
                  });
                }
              },
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

/// One revealed action panel. Shared by both sides so a leading and a trailing
/// action can never drift apart visually.
class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.width,
    required this.color,
    required this.icon,
    required this.label,
    required this.foreground,
  });

  final double width;
  final Color color;
  final IconData icon;
  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: color,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: BullSpacing.xs),
      // OverflowBox gives the icon+label column unbounded height so it lays out
      // at its natural size and centres in the panel — never asserting an
      // overflow, however short the row is (ClipRect at the root trims excess).
      child: OverflowBox(
        minHeight: 0,
        maxHeight: double.infinity,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BullIcon(icon, size: 22, color: foreground),
            const SizedBox(height: BullSpacing.xxs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
