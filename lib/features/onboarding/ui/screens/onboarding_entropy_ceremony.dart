import 'dart:async';
import 'dart:math' as math;

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/onboarding/presentation/entropy_ceremony_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// Human-entropy ceremony: the user moves a finger around the screen and
/// every qualified pointer sample is mixed into the entropy pool. Synthetic,
/// stationary, and invalid movement samples do not advance the pacing bar.
/// When the bar fills, the ceremony is finalized and wallet creation is
/// dispatched.
///
/// The trail renders only raw touch positions and the bar only the event
/// count: nothing derived from pool state is ever displayed. The hint
/// animation is a fixed Lissajous figure — decorative, unrelated to the
/// pool.
class OnboardingEntropyCeremony extends StatefulWidget {
  const OnboardingEntropyCeremony({super.key});

  @override
  State<OnboardingEntropyCeremony> createState() =>
      _OnboardingEntropyCeremonyState();
}

class _OnboardingEntropyCeremonyState extends State<OnboardingEntropyCeremony> {
  static const _maxTrailPoints = 400;
  static const _milestoneFadeAfter = Duration(milliseconds: 2200);
  static const _completePause = Duration(milliseconds: 1200);

  final List<Offset?> _trail = [];
  String _milestone = '';
  Timer? _milestoneTimer;

  @override
  void dispose() {
    _milestoneTimer?.cancel();
    super.dispose();
  }

  List<String> _milestoneMessages(BuildContext context) => [
    context.loc.onboardingEntropyMilestone1,
    context.loc.onboardingEntropyMilestone2,
    context.loc.onboardingEntropyMilestone3,
    context.loc.onboardingEntropyMilestone4,
    context.loc.onboardingEntropyMilestone5,
    context.loc.onboardingEntropyMilestone6,
    context.loc.onboardingEntropyMilestone7,
    context.loc.onboardingEntropyMilestone8,
  ];

  void _showMilestone(String message, {bool sticky = false}) {
    _milestoneTimer?.cancel();
    setState(() => _milestone = message);
    if (!sticky) {
      _milestoneTimer = Timer(_milestoneFadeAfter, () {
        if (mounted) setState(() => _milestone = '');
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final accepted = context.read<EntropyCeremonyCubit>().addPointerSample(
      kind: PointerSampleKind.move,
      pointer: event.pointer,
      x: event.position.dx,
      y: event.position.dy,
      dx: event.delta.dx,
      dy: event.delta.dy,
      timestampMicros: event.timeStamp.inMicroseconds,
      pressure: event.pressure,
      radiusMajor: event.radiusMajor,
      radiusMinor: event.radiusMinor,
      size: event.size,
      orientation: event.orientation,
      tilt: event.tilt,
      synthesized: event.synthesized,
    );
    if (!accepted) return;

    setState(() {
      _trail.add(event.localPosition);
      if (_trail.length > _maxTrailPoints) {
        _trail.removeRange(0, _trail.length - _maxTrailPoints);
      }
    });
  }

  // Taps remain a human-input path for users who cannot perform continuous
  // drag gestures. The counter is pacing, not an entropy measurement.
  void _onPointerDown(PointerDownEvent event) {
    final accepted = context.read<EntropyCeremonyCubit>().addPointerSample(
      kind: PointerSampleKind.down,
      pointer: event.pointer,
      x: event.position.dx,
      y: event.position.dy,
      dx: 0,
      dy: 0,
      timestampMicros: event.timeStamp.inMicroseconds,
      pressure: event.pressure,
      radiusMajor: event.radiusMajor,
      radiusMinor: event.radiusMinor,
      size: event.size,
      orientation: event.orientation,
      tilt: event.tilt,
      synthesized: event.synthesized,
    );
    if (!accepted) return;

    setState(() {
      _trail
        ..add(null)
        ..add(event.localPosition);
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    setState(() => _trail.add(null));
  }

  @override
  Widget build(BuildContext context) {
    final creating = context.select(
      (OnboardingBloc bloc) => bloc.state.loadingCreate,
    );
    final hasStarted = context.select(
      (EntropyCeremonyCubit cubit) => cubit.state.hasStarted,
    );
    final ceremonyComplete = context.select(
      (EntropyCeremonyCubit cubit) => cubit.state.isComplete,
    );
    final acceptingPointerInput = !creating && !ceremonyComplete;

    final ink = context.appColors.onPrimaryFixed;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: MultiBlocListener(
        listeners: [
          BlocListener<EntropyCeremonyCubit, EntropyCeremonyState>(
            listenWhen: (previous, current) =>
                previous.decile != current.decile &&
                current.decile >= 1 &&
                current.decile <= 8,
            listener: (context, state) {
              _showMilestone(_milestoneMessages(context)[state.decile - 1]);
            },
          ),
          BlocListener<EntropyCeremonyCubit, EntropyCeremonyState>(
            listenWhen: (previous, current) =>
                !previous.isComplete && current.isComplete,
            listener: (context, state) {
              _showMilestone(
                context.loc.onboardingEntropyMilestone9,
                sticky: true,
              );
              // Let the final message land before the loading state takes
              // over the screen.
              Future.delayed(_completePause, () {
                if (!mounted) return;
                context.read<OnboardingBloc>().add(
                  const OnboardingCreateNewWallet(),
                );
              });
            },
          ),
          BlocListener<OnboardingBloc, OnboardingState>(
            listenWhen: (previous, current) =>
                previous.statusError != current.statusError &&
                current.statusError.isNotEmpty,
            listener: (context, state) {
              // The shell-level listener shows the snackbar; go back to the
              // splash so the user can retry from a clean state.
              context.pop();
            },
          ),
        ],
        child: Scaffold(
          backgroundColor: context.appColors.primaryFixed,
          body: SafeArea(
            child: Stack(
              children: [
                // Full-screen capture surface: the whole screen is the
                // canvas, chrome is drawn on top and ignores pointers.
                Positioned.fill(
                  child: Semantics(
                    label: context.loc.onboardingEntropyCeremonyInstruction,
                    child: Listener(
                      onPointerDown: acceptingPointerInput
                          ? _onPointerDown
                          : null,
                      onPointerMove: acceptingPointerInput
                          ? _onPointerMove
                          : null,
                      onPointerUp: acceptingPointerInput ? _onPointerUp : null,
                      behavior: HitTestBehavior.opaque,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _TrailPainter(
                          points: List.of(_trail),
                          color: ink,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!hasStarted && !creating)
                  Positioned.fill(
                    child: IgnorePointer(child: _HintAnimation(color: ink)),
                  ),
                IgnorePointer(
                  child: Column(
                    crossAxisAlignment: .stretch,
                    children: [
                      const Gap(48),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: BBText(
                          creating
                              ? context.loc.onboardingEntropyCeremonyCreating
                              : context
                                    .loc
                                    .onboardingEntropyCeremonyInstruction,
                          style: context.font.bodyMedium?.copyWith(height: 1.6),
                          color: ink.withValues(alpha: 0.85),
                          textAlign: .center,
                          maxLines: 4,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 48,
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: BBText(
                              _milestone,
                              key: ValueKey(_milestone),
                              style: context.font.labelLarge?.copyWith(
                                letterSpacing: 1.2,
                              ),
                              color: ink,
                              textAlign: .center,
                            ),
                          ),
                        ),
                      ),
                      const Gap(24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: _ProgressLine(creating: creating, color: ink),
                      ),
                      const Gap(48),
                    ],
                  ),
                ),
                if (creating)
                  Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: ink,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single hairline with a small right-aligned percentage: the only
/// progress indication on screen.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.creating, required this.color});

  final bool creating;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = context.select(
      (EntropyCeremonyCubit cubit) => cubit.state.progress,
    );
    final value = creating ? 1.0 : progress;

    return Column(
      crossAxisAlignment: .end,
      children: [
        LinearProgressIndicator(
          value: value,
          minHeight: 1.5,
          backgroundColor: color.withValues(alpha: 0.2),
          color: color,
        ),
        const Gap(8),
        BBText(
          '${(value * 100).round()}%',
          style: context.font.labelSmall?.copyWith(letterSpacing: 2),
          color: color.withValues(alpha: 0.7),
        ),
      ],
    );
  }
}

/// Idle hint until the first touch: a dot tracing a thin Lissajous figure,
/// suggesting the gesture without instructing twice.
class _HintAnimation extends StatefulWidget {
  const _HintAnimation({required this.color});

  final Color color;

  @override
  State<_HintAnimation> createState() => _HintAnimationState();
}

class _HintAnimationState extends State<_HintAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _HintPainter(t: _controller.value, color: widget.color),
      ),
    );
  }
}

class _HintPainter extends CustomPainter {
  const _HintPainter({required this.t, required this.color});

  final double t;
  final Color color;

  Offset _lissajous(double phase, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final ax = size.width * 0.28;
    final ay = size.height * 0.18;
    return Offset(
      cx + ax * math.sin(3 * phase + math.pi / 2),
      cy + ay * math.sin(2 * phase),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final head = t * 2 * math.pi;
    const tailLength = math.pi * 0.9;
    const segments = 60;

    final paint = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    // Thin comet tail behind the dot, fading to nothing.
    for (var i = 1; i < segments; i++) {
      final a = head - tailLength * (i - 1) / segments;
      final b = head - tailLength * i / segments;
      paint.color = color.withValues(alpha: 0.35 * (1 - i / segments));
      canvas.drawLine(_lissajous(a, size), _lissajous(b, size), paint);
    }

    canvas.drawCircle(
      _lissajous(head, size),
      3,
      Paint()..color = color.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(_HintPainter oldDelegate) => oldDelegate.t != t;
}

class _TrailPainter extends CustomPainter {
  const _TrailPainter({required this.points, required this.color});

  final List<Offset?> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    for (var i = 1; i < points.length; i++) {
      final from = points[i - 1];
      final to = points[i];
      if (from == null || to == null) continue;
      // Older segments fade out so the trail feels alive without ever
      // accumulating the full gesture history on screen.
      paint.color = color.withValues(alpha: 0.1 + 0.5 * (i / points.length));
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(_TrailPainter oldDelegate) =>
      oldDelegate.points.length != points.length ||
      (points.isNotEmpty &&
          oldDelegate.points.isNotEmpty &&
          oldDelegate.points.last != points.last);
}
