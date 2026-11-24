import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bull_logger/bull_logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:screen_privacy/screen_privacy.dart';
import 'package:user_feedback/src/feedback_form.dart';
import 'package:user_feedback/src/shake_events.dart';
import 'package:user_feedback/src/ui/feedback_sheet.dart';
import 'package:user_feedback/src/ui/shake_prompt_sheet.dart';

/// Listens for a shake anywhere under [child], takes a screenshot of the
/// current screen, and offers to send feedback.
class FeedbackShakeListener extends StatefulWidget {
  const FeedbackShakeListener({
    super.key,
    required this.form,
    required this.navigatorKey,
    required this.child,
    this.currentScreen,
  });

  final FeedbackForm form;
  final GlobalKey<NavigatorState> navigatorKey;
  final String? Function()? currentScreen;
  final Widget child;

  @override
  State<FeedbackShakeListener> createState() => _FeedbackShakeListenerState();
}

class _FeedbackShakeListenerState extends State<FeedbackShakeListener> {
  final GlobalKey _boundaryKey = GlobalKey();
  StreamSubscription<void>? _subscription;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _subscription = shakeEvents().listen((_) {
      if (!_open) unawaited(_onShake());
    }, onError: _onSensorError);
  }

  void _onSensorError(Object error) {
    // No shake source (no accelerometer, plugin missing): Settings still opens the form.
    log.info('feedback shake unavailable: ${error.runtimeType}');
    unawaited(_subscription?.cancel());
  }

  Future<Uint8List?> _capture() async {
    // Never capture a recovery phrase or seed screen.
    if (ScreenCaptureProtection.instance.protectedScreenMounted) return null;
    final boundary = _boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    final image = await boundary.toImage(pixelRatio: 1.5);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _onShake() async {
    final navigatorContext = widget.navigatorKey.currentContext;
    if (navigatorContext == null) return;
    _open = true;
    try {
      final screen = widget.currentScreen?.call();
      final screenshot = await _capture(); // before any sheet covers the screen
      if (!navigatorContext.mounted) return;
      final send = await showShakePrompt(navigatorContext);
      if (!send || !navigatorContext.mounted) return;
      await showFeedbackSheet(
        navigatorContext,
        form: widget.form,
        screen: screen,
        screenshotPng: screenshot,
      );
    } finally {
      _open = false;
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(key: _boundaryKey, child: widget.child);
}
