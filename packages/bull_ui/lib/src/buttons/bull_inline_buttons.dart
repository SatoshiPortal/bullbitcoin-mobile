import '../theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// A compact text action for inline controls.
class BullInlineTextButton extends StatelessWidget {
  const BullInlineTextButton({
    super.key,
    required this.onPressed,
    required this.child,
  });
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: context.bull.text,
      minimumSize: const Size(48, 48),
    ),
    child: child,
  );
}

/// A compact icon action with an accessible tooltip.
class BullInlineIconButton extends StatelessWidget {
  const BullInlineIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.tooltip,
  });
  final VoidCallback? onPressed;
  final Widget icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    icon: icon,
    tooltip: tooltip,
    style: IconButton.styleFrom(
      foregroundColor: context.bull.text,
      minimumSize: const Size(48, 48),
    ),
  );
}
