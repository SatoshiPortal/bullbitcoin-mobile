import 'dart:async';

import 'package:bull_ui/bull_ui.dart';

/// Press-and-hold confirmation for irreversible exit steps.
///
/// The hold is the visual gesture; assistive technology gets the same action
/// through a named semantics button, so the control is never gesture-only.
class ArkHoldButton extends StatefulWidget {
  final String label;
  final String holdingLabel;
  final String hint;
  final String releasedHint;
  final VoidCallback? onConfirmed;
  final Duration duration;

  const ArkHoldButton({
    super.key,
    required this.label,
    required this.holdingLabel,
    required this.hint,
    required this.releasedHint,
    required this.onConfirmed,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ArkHoldButton> createState() => _ArkHoldButtonState();
}

class _ArkHoldButtonState extends State<ArkHoldButton> {
  static const _tick = Duration(milliseconds: 40);

  Timer? _timer;
  double _progress = 0;
  bool _released = false;

  bool get _enabled => widget.onConfirmed != null;

  @override
  void didUpdateWidget(ArkHoldButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A replaced action never inherits a hold started for the old one.
    if (!identical(oldWidget.onConfirmed, widget.onConfirmed)) _reset();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    if (!_enabled || _timer != null) return;
    final action = widget.onConfirmed;
    final step = _tick.inMicroseconds / widget.duration.inMicroseconds;
    _timer = Timer.periodic(_tick, (_) {
      if (!mounted) return;
      final next = _progress + step;
      if (next < 1) {
        setState(() => _progress = next);
        return;
      }
      _reset();
      if (action != null && identical(action, widget.onConfirmed)) action();
    });
    setState(() {
      _progress = 0;
      _released = false;
    });
  }

  void _stop() {
    if (_timer == null) return;
    _timer?.cancel();
    _timer = null;
    setState(() {
      _progress = 0;
      _released = true;
    });
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _progress = 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final background = _enabled ? colors.primary : colors.outlineVariant;
    final foreground = _enabled ? colors.onPrimary : colors.textMuted;
    final holding = _timer != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          enabled: _enabled,
          label: widget.label,
          hint: widget.hint,
          onTap: widget.onConfirmed,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _start(),
            onTapUp: (_) => _stop(),
            onTapCancel: _stop,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(context.bullShapes.button),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _progress.clamp(0, 1),
                        heightFactor: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.scrim.withAlpha(70),
                            borderRadius: BorderRadius.circular(
                              context.bullShapes.button,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: BullText(
                      holding ? widget.holdingLabel : widget.label,
                      role: BullTextRole.subtitle,
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Gap(BullSpacing.xs),
        BullText(
          _released ? widget.releasedHint : widget.hint,
          role: BullTextRole.caption,
          color: colors.textMuted,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
