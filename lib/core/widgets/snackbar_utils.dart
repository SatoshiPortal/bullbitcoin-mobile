import 'dart:async';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class SnackBarUtils {
  static OverlayEntry? _entry;
  static Timer? _timer;

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
    _disposeEntry();

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
    _disposeEntry();
  }

  static void _disposeEntry() {
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

class _SnackBarState extends State<_SnackBar> {
  double dx = 0;
  double dy = 0;

  void _endDragWithoutDismiss() {
    setState(() {
      dx = 0;
      dy = 0;
    });
    SnackBarUtils._scheduleAutoDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: (_) => SnackBarUtils._pauseAutoDismiss(),
      onHorizontalDragUpdate: (d) {
        setState(() => dx += d.delta.dx);
      },
      onHorizontalDragEnd: (d) {
        final velocity = d.primaryVelocity ?? 0;

        if (dx < -60 || velocity < -500) {
          SnackBarUtils.dismiss();
        } else {
          _endDragWithoutDismiss();
        }
      },
      onHorizontalDragCancel: _endDragWithoutDismiss,
      onVerticalDragStart: (_) => SnackBarUtils._pauseAutoDismiss(),
      onVerticalDragUpdate: (d) {
        setState(() => dy += d.delta.dy);
      },
      onVerticalDragEnd: (d) {
        final velocity = d.primaryVelocity ?? 0;

        if (dy < -60 || velocity < -500) {
          SnackBarUtils.dismiss();
        } else {
          _endDragWithoutDismiss();
        }
      },
      onVerticalDragCancel: _endDragWithoutDismiss,
      child: Transform.translate(
        offset: Offset(dx, dy),
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
    );
  }
}
