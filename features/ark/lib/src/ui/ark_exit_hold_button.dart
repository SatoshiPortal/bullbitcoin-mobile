import 'dart:async';

import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_l10n.dart';

/// A local gesture only. The parent revalidates the same review before dispatch.
class ArkExitHoldButton extends StatefulWidget {
  final bool enabled;
  final Object reviewIdentity;
  final bool Function() current;
  final VoidCallback onConfirm;
  const ArkExitHoldButton({
    super.key,
    required this.enabled,
    required this.reviewIdentity,
    required this.current,
    required this.onConfirm,
  });

  @override
  State<ArkExitHoldButton> createState() => _ArkExitHoldButtonState();
}

class _ArkExitHoldButtonState extends State<ArkExitHoldButton> {
  Timer? _timer;
  late final AppLifecycleListener _lifecycle;
  VoidCallback? _removeRouteListener;
  int _ticks = 0;
  bool _consumed = false, _asking = false;

  bool get _current =>
      mounted &&
      !_consumed &&
      widget.enabled &&
      ModalRoute.of(context)?.isCurrent == true &&
      widget.current();

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state != AppLifecycleState.resumed) _cancel();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _removeRouteListener?.call();
    final covering = ModalRoute.of(context)?.secondaryAnimation;
    covering?.addListener(_cancel);
    _removeRouteListener = () => covering?.removeListener(_cancel);
  }

  @override
  void didUpdateWidget(ArkExitHoldButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reviewIdentity != widget.reviewIdentity || !widget.enabled) {
      _cancel();
    }
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    if (mounted && _ticks != 0) setState(() => _ticks = 0);
  }

  void _finish() {
    if (!_current) return;
    _consumed = true;
    _timer?.cancel();
    _timer = null;
    widget.onConfirm();
  }

  void _start() {
    if (!_current || _asking || _timer != null) return;
    _ticks = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!_current) {
        _cancel();
      } else if (++_ticks >= 38) {
        _finish();
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _accessibleConfirm() async {
    if (!_current || _asking) return;
    _cancel();
    final identity = widget.reviewIdentity;
    _asking = true;
    final l10n = context.loc;
    try {
      final confirmed = await BullConfirmDialog.show(
        context,
        title: l10n.exitConfirmAccessible,
        message: l10n.exitNoCancellation,
        confirmLabel: l10n.confirm,
        cancelLabel: l10n.cancel,
      );
      if (confirmed &&
          mounted &&
          identity == widget.reviewIdentity &&
          _current) {
        _finish();
      }
    } finally {
      _asking = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _removeRouteListener?.call();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.loc;
    return Semantics(
      button: true,
      enabled: widget.enabled && !_consumed,
      label: l10n.exitHoldToStart,
      onTap: widget.enabled ? _accessibleConfirm : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (_) => _start(),
          onPanUpdate: (_) => _cancel(),
          onPanEnd: (_) => _cancel(),
          onPanCancel: _cancel,
          onTapUp: (_) => _cancel(),
          onTapCancel: _cancel,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.enabled
                  ? context.bull.primary
                  : context.bull.surface,
              borderRadius: BorderRadius.circular(context.bullShapes.button),
            ),
            child: BullText(
              _ticks == 0 ? l10n.exitHoldToStart : l10n.exitKeepHolding,
              role: BullTextRole.subtitle,
              color: widget.enabled
                  ? context.bull.onPrimary
                  : context.bull.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
