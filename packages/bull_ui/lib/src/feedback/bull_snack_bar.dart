import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';

/// Toast utility shown at the top of the screen, below the status bar, with an
/// optional leading icon and an action (`actionLabel` + `onAction`), e.g. the
/// unfreeze Undo toast.
class BullSnackBar {
  BullSnackBar._();

  static OverlayEntry? _entry;
  static Timer? _timer;
  static _BullSnackBarWidgetState? _activeState;

  static const Duration _displayDuration = Duration(seconds: 3);

  /// Show a message toast, optionally with a [leadingIcon] and an action
  /// (`actionLabel` + `onAction`) rendered as a tappable label (e.g. "Undo").
  static void show(
    BuildContext context, {
    required String message,
    IconData? leadingIcon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      _BullSnackBarContent(
        message: message,
        leadingIcon: leadingIcon,
        actionLabel: actionLabel,
        onAction: onAction == null
            ? null
            : () {
                dismiss();
                onAction();
              },
      ),
    );
  }

  /// Show a toast with custom [content] instead of a plain message.
  static void showContent(BuildContext context, Widget content) {
    _show(context, content);
  }

  static void _show(BuildContext context, Widget content) {
    _disposeEntryImmediate();
    _entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 0,
        left: 16,
        right: 16,
        child: SafeArea(
          bottom: false,
          minimum: const EdgeInsets.only(top: 8),
          // Size the bubble to its content and centre it, so the trailing
          // action (e.g. "Undo") hugs the message instead of being stranded at
          // the far edge of a forced full-width bar.
          child: Align(
            alignment: Alignment.topCenter,
            child: _BullSnackBarWidget(content: content),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    _scheduleAutoDismiss();
  }

  /// Dismiss the active toast (animated when possible).
  static void dismiss() {
    final state = _activeState;
    if (state != null && !state._dismissing && state.mounted) {
      state._beginDismiss(direction: const Offset(0, -1));
    } else {
      _disposeEntryImmediate();
    }
  }

  static void _completeDismiss() => _disposeEntryImmediate();

  static void _disposeEntryImmediate() {
    _timer?.cancel();
    _timer = null;
    final entry = _entry;
    if (entry != null && entry.mounted) entry.remove();
    _entry = null;
  }

  static void _scheduleAutoDismiss() {
    _timer?.cancel();
    _timer = Timer(_displayDuration, dismiss);
  }

  static void _pauseAutoDismiss() {
    _timer?.cancel();
    _timer = null;
  }
}

class _BullSnackBarContent extends StatelessWidget {
  const _BullSnackBarContent({
    required this.message,
    this.leadingIcon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData? leadingIcon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final hasAction = actionLabel != null && onAction != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leadingIcon != null) ...[
          BullIcon(leadingIcon!, size: 20, color: colors.text),
          const SizedBox(width: 12),
        ],
        Flexible(
          child: Text(
            message,
            // Centred in the pill, so a wrapped message stays balanced; with an
            // action the message keeps to the start, next to it.
            textAlign: hasAction ? TextAlign.start : TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.text),
          ),
        ),
        if (hasAction) ...[
          const SizedBox(width: 16),
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              // Error reads as a warm red on both the light and the dark toast.
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BullSnackBarWidget extends StatefulWidget {
  const _BullSnackBarWidget({required this.content});

  final Widget content;

  @override
  State<_BullSnackBarWidget> createState() => _BullSnackBarWidgetState();
}

class _BullSnackBarWidgetState extends State<_BullSnackBarWidget>
    with SingleTickerProviderStateMixin {
  static const Offset _enterFromOffset = Offset(0, -120);

  Offset _offset = _enterFromOffset;
  double _opacity = 0;
  bool _dismissing = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    BullSnackBar._activeState = this;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _runAnim(
      toOffset: Offset.zero,
      toOpacity: 1.0,
      curve: Curves.easeOutCubic,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    if (BullSnackBar._activeState == this) {
      BullSnackBar._activeState = null;
    }
    _controller.dispose();
    super.dispose();
  }

  void _runAnim({
    required Offset toOffset,
    required double toOpacity,
    required Curve curve,
    required Duration duration,
    VoidCallback? onComplete,
  }) {
    final fromOffset = _offset;
    final fromOpacity = _opacity;
    _controller.duration = duration;
    final anim = CurvedAnimation(parent: _controller, curve: curve);
    void listener() {
      if (!mounted) return;
      setState(() {
        _offset = Offset.lerp(fromOffset, toOffset, anim.value)!;
        _opacity = (fromOpacity + (toOpacity - fromOpacity) * anim.value).clamp(
          0.0,
          1.0,
        );
      });
    }

    anim.addListener(listener);
    _controller
      ..reset()
      ..forward().whenComplete(() {
        anim.removeListener(listener);
        if (mounted && onComplete != null) onComplete();
      });
  }

  void _beginDismiss({required Offset direction}) {
    if (_dismissing) return;
    _dismissing = true;
    final screen = MediaQuery.sizeOf(context);
    final target = Offset(
      direction.dx == 0
          ? _offset.dx
          : direction.dx * (screen.width * 0.7 + 100),
      direction.dy == 0
          ? _offset.dy
          : direction.dy * (screen.height * 0.4 + 100),
    );
    _runAnim(
      toOffset: target,
      toOpacity: 0,
      curve: Curves.easeIn,
      duration: const Duration(milliseconds: 220),
      onComplete: BullSnackBar._completeDismiss,
    );
  }

  void _snapBack() {
    _runAnim(
      toOffset: Offset.zero,
      toOpacity: 1,
      curve: Curves.easeOutCubic,
      duration: const Duration(milliseconds: 220),
    );
    BullSnackBar._scheduleAutoDismiss();
  }

  void _onDragStart() {
    if (_dismissing) return;
    _controller.stop(canceled: true);
    BullSnackBar._pauseAutoDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return GestureDetector(
      onHorizontalDragStart: (_) => _onDragStart(),
      onHorizontalDragUpdate: (d) {
        if (_dismissing) return;
        setState(() => _offset = _offset.translate(d.delta.dx, 0));
      },
      onHorizontalDragEnd: (d) {
        if (_dismissing) return;
        final v = d.primaryVelocity ?? 0;
        if (_offset.dx.abs() > 60 || v.abs() > 500) {
          final sign = _offset.dx != 0 ? _offset.dx.sign : v.sign;
          _beginDismiss(direction: Offset(sign, 0));
        } else {
          _snapBack();
        }
      },
      onHorizontalDragCancel: () {
        if (!_dismissing) _snapBack();
      },
      onVerticalDragStart: (_) => _onDragStart(),
      onVerticalDragUpdate: (d) {
        if (_dismissing) return;
        setState(() => _offset = _offset.translate(0, d.delta.dy));
      },
      onVerticalDragEnd: (d) {
        if (_dismissing) return;
        final v = d.primaryVelocity ?? 0;
        if (_offset.dy.abs() > 60 || v.abs() > 500) {
          final sign = _offset.dy != 0 ? _offset.dy.sign : v.sign;
          _beginDismiss(direction: Offset(0, sign));
        } else {
          _snapBack();
        }
      },
      onVerticalDragCancel: () {
        if (!_dismissing) _snapBack();
      },
      child: Transform.translate(
        offset: _offset,
        child: Opacity(
          opacity: _opacity,
          child: Material(
            color: Colors.transparent,
            // The shadow sits outside the clip, so the rounded clip below
            // doesn't cut it off.
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(BullRadius.xxs),
                boxShadow: [
                  BoxShadow(
                    // Translucent black in both themes, so it never glows.
                    color: colors.scrim,
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(BullRadius.xxs),
                // Frosted glass: whatever is behind the pill is blurred, so it
                // reads as a soft wash instead of competing with the message.
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    // Follows the theme: a light grey in light mode, a dark
                    // grey in dark mode — set apart from both the screen
                    // background and the cards on it.
                    decoration: BoxDecoration(
                      // Slightly see-through, over the blurred backdrop.
                      color: colors.surfaceContainerHighest.withValues(
                        alpha: 0.85,
                      ),
                      borderRadius: BorderRadius.circular(BullRadius.xxs),
                      border: Border.all(color: colors.secondaryFixedDim),
                    ),
                    child: widget.content,
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
