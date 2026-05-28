import 'dart:async';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class SnackBarUtils {
  static OverlayEntry? _entry;
  static Timer? _timer;
  static _SnackBarState? _activeState;

  static const Duration _displayDuration = Duration(seconds: 3);

  static void showCopiedSnackBar(BuildContext context) {
    _show(
      context,
      Text(
        'Copied to clipboard',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: context.appColors.surface),
      ),
    );
  }

  static void showSnackBar(BuildContext context, String message) {
    _show(
      context,
      Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: context.appColors.surface),
      ),
    );
  }

  static void showSnackBarWithContent(BuildContext context, Widget content) {
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
          child: _SnackBar(content: content),
        ),
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_entry!);

    _scheduleAutoDismiss();
  }

  static void dismiss() {
    final state = _activeState;
    if (state != null && !state._dismissing && state.mounted) {
      state._beginDismiss(direction: const Offset(0, -1));
    } else {
      _disposeEntryImmediate();
    }
  }

  static void _completeDismiss() {
    _disposeEntryImmediate();
  }

  static void _disposeEntryImmediate() {
    _timer?.cancel();
    _timer = null;
    final entry = _entry;
    if (entry != null && entry.mounted) {
      entry.remove();
    }
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

class _SnackBar extends StatefulWidget {
  final Widget content;

  const _SnackBar({required this.content});

  @override
  State<_SnackBar> createState() => _SnackBarState();
}

class _SnackBarState extends State<_SnackBar>
    with SingleTickerProviderStateMixin {
  static const Offset _enterFromOffset = Offset(0, -120);

  Offset _offset = _enterFromOffset;
  double _opacity = 0;
  bool _dismissing = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    SnackBarUtils._activeState = this;
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
    if (SnackBarUtils._activeState == this) {
      SnackBarUtils._activeState = null;
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
      onComplete: SnackBarUtils._completeDismiss,
    );
  }

  void _snapBack() {
    _runAnim(
      toOffset: Offset.zero,
      toOpacity: 1,
      curve: Curves.easeOutCubic,
      duration: const Duration(milliseconds: 220),
    );
    SnackBarUtils._scheduleAutoDismiss();
  }

  void _onDragStart() {
    if (_dismissing) return;
    _controller.stop(canceled: true);
    SnackBarUtils._pauseAutoDismiss();
  }

  @override
  Widget build(BuildContext context) {
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: context.appColors.onSurface.withAlpha(204),
                borderRadius: BorderRadius.circular(20),
              ),
              child: widget.content,
            ),
          ),
        ),
      ),
    );
  }
}
