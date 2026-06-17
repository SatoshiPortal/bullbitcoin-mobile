import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// A compact "Sync" text button whose leading icon spins while [syncing] is
/// true. **New.** Encapsulates the rotation animation so feature code (which may
/// only import `package:bull_ui/bull_ui.dart`) needs no animation primitives.
class BullSyncButton extends StatefulWidget {
  const BullSyncButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.syncing = false,
  });

  /// Button label (e.g. "Sync").
  final String label;

  /// Tap callback.
  final VoidCallback onPressed;

  /// When true, the leading sync icon rotates continuously.
  final bool syncing;

  @override
  State<BullSyncButton> createState() => _BullSyncButtonState();
}

class _BullSyncButtonState extends State<BullSyncButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void initState() {
    super.initState();
    if (widget.syncing) _controller.repeat();
  }

  @override
  void didUpdateWidget(BullSyncButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.syncing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.syncing && _controller.isAnimating) {
      _controller
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return GestureDetector(
      onTap: widget.onPressed,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _controller,
            child: BullIcon(BullIcons.sync, size: 16, color: colors.primary),
          ),
          const SizedBox(width: 4),
          Text(
            widget.label,
            style: context.bullText.labelMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
