import 'dart:math' as math;

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

enum TorBullState { idle, direct, filtered, snowflake, ready, failed }

class TorBullMascot extends StatefulWidget {
  final TorBullState state;
  final String semanticLabel;

  const TorBullMascot({
    required this.state,
    required this.semanticLabel,
    super.key,
  });

  @override
  State<TorBullMascot> createState() => _TorBullMascotState();
}

class _TorBullMascotState extends State<TorBullMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _moves => switch (widget.state) {
    TorBullState.direct ||
    TorBullState.filtered ||
    TorBullState.snowflake => true,
    TorBullState.idle || TorBullState.ready || TorBullState.failed => false,
  };

  String get _asset => switch (widget.state) {
    TorBullState.idle ||
    TorBullState.direct => 'assets/animations/tor_bull_searching.png',
    TorBullState.filtered => 'assets/animations/tor_bull_filtered.png',
    TorBullState.snowflake => 'assets/animations/tor_bull_snowflake.png',
    TorBullState.ready => 'assets/animations/tor_bull_ready.png',
    TorBullState.failed => 'assets/animations/tor_bull_failed.png',
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimation();
  }

  @override
  void didUpdateWidget(TorBullMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _updateAnimation();
  }

  void _updateAnimation() {
    if (_moves && !MediaQuery.disableAnimationsOf(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: widget.semanticLabel,
    child: SizedBox(
      key: ValueKey('tor-bull-${widget.state.name}'),
      width: 220,
      height: 190,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final wave = math.sin(_controller.value * math.pi * 2);
          final floats =
              widget.state == TorBullState.direct ||
              widget.state == TorBullState.snowflake;
          final lift = floats ? 5 + wave * 3 : 0.0;
          final shake = widget.state == TorBullState.filtered
              ? math.sin(_controller.value * math.pi * 8) * 2.5
              : 0.0;

          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                bottom: 2,
                child: Transform.scale(
                  scaleX: 1 - lift / 70,
                  child: Container(
                    width: 70,
                    height: 9,
                    decoration: BoxDecoration(
                      color: context.appColors.scrim.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(shake, -lift),
                child: Opacity(
                  opacity: widget.state == TorBullState.idle ? 0.58 : 1,
                  child: Image.asset(
                    _asset,
                    key: ValueKey(_asset),
                    width: 220,
                    height: 190,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
