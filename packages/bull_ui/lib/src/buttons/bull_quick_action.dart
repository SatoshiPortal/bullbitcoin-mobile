import 'dart:async';

import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A compact, accessible shortcut with a stable height across text scales.
class BullQuickAction extends StatelessWidget {
  const BullQuickAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.onLongPress,
    this.semanticLabel,
    this.outlined = false,
    this.disabled = false,
    super.key,
  });

  static const double height = 100;

  final String label;
  final String? semanticLabel;
  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final bool outlined;
  final bool disabled;

  void _activate(VoidCallback callback) {
    unawaited(HapticFeedback.selectionClick());
    callback();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final tap = disabled ? null : () => _activate(onPressed);
    final longPressCallback = onLongPress;
    final longPress = disabled || longPressCallback == null
        ? null
        : () => _activate(longPressCallback);
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      enabled: !disabled,
      onTap: tap,
      onLongPress: longPress,
      child: ExcludeSemantics(
        child: Tooltip(
          message: semanticLabel ?? label,
          excludeFromSemantics: true,
          triggerMode: longPress == null
              ? TooltipTriggerMode.longPress
              : TooltipTriggerMode.manual,
          child: SizedBox(
            height: height,
            child: Opacity(
              opacity: disabled ? 0.4 : 1,
              child: Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: tap,
                  onLongPress: longPress,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 4,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: outlined
                                ? colors.transparent
                                : colors.surfaceContainerHighest,
                            border: outlined
                                ? Border.all(color: colors.border)
                                : null,
                          ),
                          child: Center(
                            child: BullIcon(icon, size: 24, color: colors.text),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
