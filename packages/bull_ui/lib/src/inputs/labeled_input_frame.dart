import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/layout/gap.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:material_ui/material_ui.dart';

/// The bold label and bordered, shadowed card shared by the labelled inputs.
///
/// Internal to `bull_ui`: the labelled inputs expose it through their own
/// API, so the look stays in one place.
class LabeledInputFrame extends StatelessWidget {
  const LabeledInputFrame({
    super.key,
    required this.label,
    required this.child,
  });

  /// Label shown above the field.
  final String label;

  /// The field set in the card.
  final Widget child;

  /// The text style the labelled inputs use for their value and placeholder.
  static TextStyle? fieldStyle(BuildContext context, Color color) =>
      Theme.of(context).textTheme.bodySmall
          ?.copyWith(fontWeight: FontWeight.w700, fontSize: 14, color: color);

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BullText(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.text,
            letterSpacing: 0,
            fontSize: 14,
          ),
        ),
        const Gap(8),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(context.bullShapes.card),
            border: Border.all(color: colors.border, width: 0.69),
            boxShadow: [
              BoxShadow(color: colors.border, offset: const Offset(0, 2)),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}
