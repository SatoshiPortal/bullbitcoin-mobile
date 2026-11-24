import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../theme/payment_animation_palette.dart';
import 'payment_scenes.dart';

export 'payment_scenes.dart' show BullPaymentNetwork, BullPaymentPhase;

/// Decorative payment scene. Only the caller decides the payment outcome.
class BullPaymentAnimation extends StatefulWidget {
  final BullPaymentNetwork network;
  final BullPaymentPhase phase;
  final VoidCallback? onImpact;
  final VoidCallback? onDone;

  const BullPaymentAnimation({
    super.key,
    required this.network,
    required this.phase,
    this.onImpact,
    this.onDone,
  });

  @override
  State<BullPaymentAnimation> createState() => _BullPaymentAnimationState();
}

class _BullPaymentAnimationState extends State<BullPaymentAnimation>
    with SingleTickerProviderStateMixin {
  final _frame = _PaymentFrame();
  late final Ticker _ticker;
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<AccelerometerEvent>? _motion;
  bool _visible = false;
  bool _reduced = false;
  bool _impacted = false;
  bool _done = false;
  Duration? _lastTick;
  double _targetRoll = 0;
  double _springVelocity = 0;

  double? get _badgeAt => switch ((widget.network, widget.phase)) {
    (
      BullPaymentNetwork.bitcoin || BullPaymentNetwork.ark,
      BullPaymentPhase.success,
    ) =>
      1.1,
    (BullPaymentNetwork.lightning, BullPaymentPhase.success) => 1,
    (BullPaymentNetwork.liquid, BullPaymentPhase.success) => 1.2,
    (BullPaymentNetwork.bitcoin, BullPaymentPhase.failed) => 1.5,
    (BullPaymentNetwork.lightning, BullPaymentPhase.failed) => 1.4,
    (_, BullPaymentPhase.failed) => 1.6,
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _lifecycle = AppLifecycleListener(onStateChange: (_) => _updateActivity());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    if (_reduced != reduced) {
      _reduced = reduced;
      _frame.resetPose();
      _springVelocity = 0;
    }
    _updateActivity();
  }

  @override
  void didUpdateWidget(BullPaymentAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.phase != oldWidget.phase ||
        widget.network != oldWidget.network) {
      _frame.elapsed = 0;
      _impacted = false;
      _done = false;
      _updateActivity();
    }
  }

  void _updateActivity() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final active =
        _visible &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    if (!active || _reduced || _done) {
      _ticker.stop();
      _lastTick = null;
      unawaited(_motion?.cancel());
      _motion = null;
      _targetRoll = 0;
      if (active && _reduced && !_done && _badgeAt != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _reduced && _badgeAt != null && !_done) _finish();
        });
      }
      return;
    }
    if (!_ticker.isActive) _ticker.start();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _motion ??=
          accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
              .listen((event) {
                final angle = math.atan2(event.x, event.y.abs());
                if (angle.isFinite) _targetRoll = angle.clamp(-0.35, 0.35);
              }, onError: (Object _) => _targetRoll = 0);
    }
  }

  void _tick(Duration timestamp) {
    final delta = timestamp - (_lastTick ?? timestamp);
    _lastTick = timestamp;
    final elapsed = delta.inMicroseconds / 1e6;
    final dt = math.min(0.04, elapsed);
    _frame.elapsed += elapsed;
    _frame.time += elapsed;
    _frame.roll += (_targetRoll - _frame.roll) * math.min(1, dt * 9);
    _springVelocity +=
        ((-_frame.roll - _frame.springRoll) * 40 - _springVelocity * 9) * dt;
    _frame.springRoll += _springVelocity * dt;
    _frame.repaint();
    final badgeAt = _badgeAt;
    if (badgeAt == null) return;
    if (!_impacted && _frame.elapsed >= badgeAt) {
      _impacted = true;
      widget.onImpact?.call();
    }
    if (_frame.elapsed >= badgeAt + 0.5) _finish();
  }

  void _finish() {
    _done = true;
    _updateActivity();
    widget.onDone?.call();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_motion?.cancel());
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _PaymentPainter(
              _frame,
              widget.network,
              widget.phase,
              _reduced,
              Theme.of(context).extension<PaymentAnimationPalette>() ??
                  PaymentAnimationPalette.standard,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _PaymentFrame extends ChangeNotifier {
  final scenes = PaymentScenes();
  double elapsed = 0;
  double time = 0;
  double roll = 0;
  double springRoll = 0;

  void repaint() => notifyListeners();

  void resetPose() {
    roll = 0;
    springRoll = 0;
  }
}

class _PaymentPainter extends CustomPainter {
  final _PaymentFrame frame;
  final BullPaymentNetwork network;
  final BullPaymentPhase phase;
  final bool reduced;
  final PaymentAnimationPalette palette;

  _PaymentPainter(
    this.frame,
    this.network,
    this.phase,
    this.reduced,
    this.palette,
  ) : super(repaint: frame);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    frame.scenes.paint(
      canvas,
      size,
      network: network,
      phase: phase,
      elapsed: reduced ? 3 : frame.elapsed,
      time: reduced ? 0 : frame.time,
      roll: reduced ? 0 : frame.roll,
      springRoll: reduced ? 0 : frame.springRoll,
      palette: palette,
    );
  }

  @override
  bool shouldRepaint(_PaymentPainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.network != network ||
      oldDelegate.phase != phase ||
      oldDelegate.reduced != reduced ||
      oldDelegate.palette != palette;
}
