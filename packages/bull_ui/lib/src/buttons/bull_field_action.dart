import 'package:material_ui/material_ui.dart';

import '../theme/bull_shapes.dart';
import '../theme/bull_theme.dart';
import '../theme/bull_tokens.dart';
import '../theme/bull_typography.dart';

/// A secondary field action: 48×40 fill inside a 48×48 touch target.
class BullFieldAction extends StatelessWidget {
  const BullFieldAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.child,
  }) : assert(icon == null || child == null);

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Decorative content for a field action owned by the supplied callback.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final content = child;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      focusable: onPressed != null,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            onLongPress: onPressed == null ? null : () {},
            highlightColor: context.bull.onSecondary.withValues(alpha: 0.16),
            splashColor: context.bull.onSecondary.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(context.bullShapes.button),
            child: SizedBox(
              width: BullSpacing.xxl,
              height: BullSpacing.xxl,
              child: Center(
                child: SizedBox(
                  width: BullSpacing.xxl,
                  height: BullSpacing.xl + BullSpacing.xs,
                  child: Ink(
                    decoration: BoxDecoration(
                      color: onPressed == null
                          ? context.bull.secondary.withValues(alpha: 0.5)
                          : context.bull.secondary,
                      borderRadius: BorderRadius.circular(
                        context.bullShapes.button,
                      ),
                    ),
                    child: Center(
                      child: content != null
                          ? DefaultTextStyle.merge(
                              style: TextStyle(color: context.bull.onSecondary),
                              child: IconTheme.merge(
                                data: IconThemeData(
                                  color: context.bull.onSecondary,
                                ),
                                child: content,
                              ),
                            )
                          : icon != null
                          ? Icon(icon, color: context.bull.onSecondary)
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.bullType.label.copyWith(
                                  color: context.bull.onSecondary,
                                ),
                              ),
                            ),
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
