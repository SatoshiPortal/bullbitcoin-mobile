import 'dart:async';

import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// The single application toast implementation.
class BullSnackBar {
  BullSnackBar._();

  static OverlayEntry? _entry;
  static Timer? _timer;
  static _BullSnackBarWidgetState? _activeState;
  static const _displayDuration = Duration(seconds: 3);

  static void show(
    BuildContext context, {
    required String message,
    IconData? leadingIcon,
    String? actionLabel,
    VoidCallback? onAction,
  }) => showContent(
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

  /// Shows custom content using the same canonical toast surface and behavior.
  static void showContent(BuildContext context, Widget content) {
    _disposeEntryImmediate();
    _entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 0,
        left: 16,
        right: 16,
        child: SafeArea(
          bottom: false,
          minimum: const EdgeInsets.only(top: 8),
          child: _BullSnackBarWidget(content: content),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    _scheduleAutoDismiss();
  }

  static void dismiss() {
    final state = _activeState;
    if (state != null && !state._dismissing && state.mounted) {
      state._beginDismiss(const Offset(0, -1));
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
    final foreground = context.bull.onSecondaryFixed;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leadingIcon != null) ...[
          BullIcon(leadingIcon!, size: 20, color: foreground),
          const SizedBox(width: 12),
        ],
        Flexible(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: foreground, fontSize: 14),
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 16),
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: foreground,
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
  Offset _offset = const Offset(0, -120);
  Offset _dragOffset = Offset.zero;
  double _opacity = 0;
  bool _dismissing = false;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    BullSnackBar._activeState = this;
    _controller = AnimationController(vsync: this);
    _runAnim(
      Offset.zero,
      1,
      const Duration(milliseconds: 250),
      Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    if (BullSnackBar._activeState == this) BullSnackBar._activeState = null;
    _controller.dispose();
    super.dispose();
  }

  void _runAnim(
    Offset target,
    double opacity,
    Duration duration,
    Curve curve, [
    VoidCallback? done,
  ]) {
    final fromOffset = _offset;
    final fromOpacity = _opacity;
    _controller.duration = duration;
    final animation = CurvedAnimation(parent: _controller, curve: curve);
    void listener() {
      if (!mounted) return;
      setState(() {
        _offset = Offset.lerp(fromOffset, target, animation.value)!;
        _opacity = (fromOpacity + (opacity - fromOpacity) * animation.value)
            .clamp(0, 1);
      });
    }

    animation.addListener(listener);
    _controller
      ..reset()
      ..forward().whenComplete(() {
        animation.removeListener(listener);
        if (mounted) done?.call();
      });
  }

  void _beginDismiss(Offset direction) {
    if (_dismissing) return;
    _dismissing = true;
    final size = MediaQuery.sizeOf(context);
    _runAnim(
      Offset(
        direction.dx * (size.width * .7 + 100),
        direction.dy * (size.height * .4 + 100),
      ),
      0,
      const Duration(milliseconds: 220),
      Curves.easeIn,
      BullSnackBar._completeDismiss,
    );
  }

  void _onDragStart() {
    if (_dismissing) return;
    _dragOffset = Offset.zero;
    _controller.stop(canceled: true);
    BullSnackBar._pauseAutoDismiss();
  }

  void _snapBack() {
    _runAnim(
      Offset.zero,
      1,
      const Duration(milliseconds: 220),
      Curves.easeOutCubic,
    );
    BullSnackBar._scheduleAutoDismiss();
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dismissing) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset.dx.abs() > 60 || velocity.abs() > 500) {
      final sign = (_dragOffset.dx == 0 ? velocity : _dragOffset.dx).sign;
      _beginDismiss(Offset(sign, 0));
    } else {
      _snapBack();
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_dismissing) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset.dy.abs() > 60 || velocity.abs() > 500) {
      final sign = (_dragOffset.dy == 0 ? velocity : _dragOffset.dy).sign;
      _beginDismiss(Offset(0, sign));
    } else {
      _snapBack();
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onHorizontalDragStart: (_) => _onDragStart(),
    onHorizontalDragUpdate: (d) => setState(() {
      _dragOffset += Offset(d.delta.dx, 0);
      _offset += Offset(d.delta.dx, 0);
    }),
    onHorizontalDragEnd: _onHorizontalDragEnd,
    onHorizontalDragCancel: _snapBack,
    onVerticalDragStart: (_) => _onDragStart(),
    onVerticalDragUpdate: (d) => setState(() {
      _dragOffset += Offset(0, d.delta.dy);
      _offset += Offset(0, d.delta.dy);
    }),
    onVerticalDragEnd: _onVerticalDragEnd,
    onVerticalDragCancel: _snapBack,
    child: Transform.translate(
      offset: _offset,
      child: Opacity(
        opacity: _opacity,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: context.bull.secondaryFixed.withValues(alpha: .8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: widget.content,
          ),
        ),
      ),
    ),
  );
}
