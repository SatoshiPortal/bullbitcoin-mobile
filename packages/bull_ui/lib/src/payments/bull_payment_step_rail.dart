import 'package:material_ui/material_ui.dart';

import '../../generated/l10n/bull_ui_localizations.dart';
import '../theme/bull_tokens.dart';
import '../theme/bull_typography.dart';
import '../theme/payment_animation_palette.dart';
import 'bull_payment_progress.dart';
import 'payment_scenes.dart';

/// Segmented rail of a payment's real steps with its textual state: one
/// segment per status (passed white, current pulsing white, broadcast orange,
/// held grey, final green,
/// pending hollow grey, failed red and taller), "Step n of m · label" and the
/// number of steps left. Announced as one live region; static under reduced
/// motion.
class BullPaymentStepRail extends StatefulWidget {
  final BullPaymentProgress progress;
  final BullPaymentNetwork network;
  final BullPaymentPhase phase;
  final PaymentAnimationPalette palette;
  final bool reduced;

  const BullPaymentStepRail({
    super.key,
    required this.progress,
    required this.network,
    required this.phase,
    required this.palette,
    required this.reduced,
  });

  @override
  State<BullPaymentStepRail> createState() => _BullPaymentStepRailState();
}

class _BullPaymentStepRailState extends State<BullPaymentStepRail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(BullPaymentStepRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  int? get _failedIndex {
    final failed = widget.progress.failedAt;
    if (failed != null) return failed;
    if (widget.phase != BullPaymentPhase.failed) return null;
    final current = widget.progress.current;
    return current ?? widget.progress.total - 1;
  }

  bool get _pulsing =>
      !widget.reduced &&
      _failedIndex == null &&
      widget.phase != BullPaymentPhase.success &&
      !widget.progress.isComplete;

  void _syncPulse() {
    if (_pulsing) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final palette = widget.palette;
    final l10n = BullUiLocalizations.of(context);
    final failed = _failedIndex;
    final success = widget.phase == BullPaymentPhase.success;
    final shown = success
        ? progress.total - 1
        : failed ?? progress.current ?? progress.total - 1;
    final broadcast =
        failed == null &&
        !success &&
        progress.currentState == BullPaymentStepState.broadcast;
    final label = progress.steps[shown];
    final stepText = failed == null
        ? l10n.paymentStepOf(shown + 1, progress.total, label)
        : l10n.paymentStepFailed(shown + 1, progress.total, label);
    final leftText = failed == null
        ? l10n.paymentStepsLeft(
            // Statuses still ahead of the current one. A payment sitting in
            // its last status without the success phase is not complete yet.
            success || progress.isComplete
                ? 0
                : (progress.total - 1 - shown).clamp(1, progress.total),
          )
        : null;
    final type = context.bullType;
    return Semantics(
      container: true,
      liveRegion: true,
      label: leftText == null ? stepText : '$stepText. $leftText',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: BullSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => Row(
                  children: [
                    for (var i = 0; i < progress.total; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: i == progress.total - 1 ? 0 : 4,
                          ),
                          child: SizedBox(
                            height: 12,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _segment(i, failed, palette),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: BullSpacing.xs),
              Text(
                stepText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: type.label.copyWith(
                  color: broadcast
                      ? palette.broadcast
                      : success
                      ? palette.success
                      : palette.foreground,
                ),
              ),
              if (leftText != null)
                Text(
                  leftText,
                  style: type.caption.copyWith(color: palette.gray),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segment(int i, int? failed, PaymentAnimationPalette p) {
    final progress = widget.progress;
    if (i == failed) {
      // A refund is never a loss: grey while it can be broadcast, white once
      // the funds are back. Only a stop without a refund is red.
      return switch (progress.refund) {
        BullPaymentRefund.available => Container(height: 6, color: p.gray),
        BullPaymentRefund.done => Container(height: 6, color: p.foreground),
        null => Container(height: 10, color: p.failure),
      };
    }
    if (i == progress.skippedAt) {
      // Bypassed without failing: grey and filled, neither done nor red.
      return Container(height: 4, color: p.gray.withValues(alpha: .55));
    }
    if (failed != null && i > failed) return _pending(p);
    if (widget.phase == BullPaymentPhase.success) {
      return Container(
        height: i == progress.total - 1 ? 6 : 4,
        color: i == progress.total - 1 ? p.success : p.foreground,
      );
    }
    if (i < progress.completed) {
      return Container(height: 4, color: p.foreground);
    }
    if (i == progress.completed) {
      final alpha = widget.reduced ? 1.0 : .45 + .55 * _pulse.value;
      return switch (progress.currentState) {
        BullPaymentStepState.active => Container(
          height: 6,
          color: p.foreground.withValues(alpha: alpha),
        ),
        BullPaymentStepState.broadcast => Container(
          height: 6,
          color: p.broadcast.withValues(alpha: alpha),
        ),
        // Uncertain or waiting: steady grey, neither progress nor failure.
        BullPaymentStepState.held => Container(height: 6, color: p.gray),
      };
    }
    return _pending(p);
  }

  Widget _pending(PaymentAnimationPalette p) => Container(
    height: 4,
    decoration: BoxDecoration(
      border: Border.all(color: p.gray.withValues(alpha: .7)),
    ),
  );
}
