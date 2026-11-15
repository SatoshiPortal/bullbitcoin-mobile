import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// A titled section of a dashboard: a bordered surface with a heading row
/// above its content.
class BullPanel extends StatelessWidget {
  const BullPanel({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = const EdgeInsets.all(BullSpacing.lg),
  });

  final String title;
  final Widget child;

  /// A text action at the end of the heading row, e.g. "View all".
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Shown at the end of the heading row instead of the text action.
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final textTheme = Theme.of(context).textTheme;
    final actionLabel = this.actionLabel;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.bullShapes.card),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing case final trailing?)
                  trailing
                else if (actionLabel != null)
                  InkWell(
                    onTap: onAction,
                    borderRadius: BorderRadius.circular(
                      context.bullShapes.button,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BullSpacing.xs,
                        vertical: BullSpacing.xxs,
                      ),
                      child: Text(
                        actionLabel,
                        style: textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: BullSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}
