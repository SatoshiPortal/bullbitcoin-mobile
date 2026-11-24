import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/bull_tokens.dart';
import '../theme/bull_typography.dart';
import '../theme/payment_animation_palette.dart';
import 'bull_payment_animation.dart';

/// Hosts the presentation of one payment attempt. Skipping dismisses only
/// the presentation; neither callback starts, cancels, or settles a payment.
class BullPaymentTransition extends StatefulWidget {
  final BullPaymentNetwork network;
  final BullPaymentPhase phase;
  final String status;
  final String skipLabel;
  final VoidCallback? onSkip;
  final VoidCallback? onBackdropTap;
  final VoidCallback onDone;

  const BullPaymentTransition({
    super.key,
    required this.network,
    required this.phase,
    required this.status,
    required this.skipLabel,
    required this.onSkip,
    this.onBackdropTap,
    required this.onDone,
  });

  @override
  State<BullPaymentTransition> createState() => _BullPaymentTransitionState();
}

class _BullPaymentTransitionState extends State<BullPaymentTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  late final AppLifecycleListener _lifecycle;
  late final String _initialStatus;
  bool _canAdvance = false;
  bool _reduced = false;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _initialStatus = widget.status;
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addStatusListener(_introStatus);
    _lifecycle = AppLifecycleListener(onStateChange: (_) => _updateIntro());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    _visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    _updateIntro();
  }

  void _updateIntro() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (_reduced ||
        _canAdvance ||
        !_visible ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed)) {
      _intro.stop();
    } else if (!_intro.isAnimating) {
      _intro.forward();
    }
  }

  void _introStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() => _canAdvance = true);
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showIntro = !_reduced && !_canAdvance;
    final palette =
        Theme.of(context).extension<PaymentAnimationPalette>() ??
        PaymentAnimationPalette.standard;
    final onSkip = widget.onSkip;
    return Listener(
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: palette.background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            BullPaymentAnimation(
              network: widget.network,
              phase: showIntro ? BullPaymentPhase.initiated : widget.phase,
              onImpact: HapticFeedback.mediumImpact,
              onDone: widget.onDone,
            ),
            if (widget.onBackdropTap case final onBackdropTap?)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: onBackdropTap,
              ),
            SafeArea(
              minimum: const EdgeInsets.all(BullSpacing.lg),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        palette.background.withValues(alpha: 0),
                        palette.background,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(BullSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            showIntro ? _initialStatus : widget.status,
                            style: context.bullType.display.copyWith(
                              fontFamily: BullTypography.brandFamily,
                              color: palette.foreground,
                            ),
                          ),
                        ),
                        if (onSkip != null)
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: palette.foreground,
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: onSkip,
                            child: Text(widget.skipLabel),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
