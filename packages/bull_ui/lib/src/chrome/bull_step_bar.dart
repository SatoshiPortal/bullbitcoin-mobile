import 'package:material_ui/material_ui.dart';

import '../theme/bull_theme.dart';
import '../theme/bull_tokens.dart';
import '../theme/bull_typography.dart';

/// Horizontal progress through a labelled sequence; [currentStep] is zero-based.
/// The caller supplies a translated status for each marker's semantics.
class BullStepBar extends StatelessWidget {
  const BullStepBar({
    super.key,
    required this.labels,
    required this.currentStep,
    required this.semanticLabel,
  }) : assert(labels.length > 1),
       assert(currentStep >= 0 && currentStep < labels.length);

  final List<String> labels;
  final int currentStep;
  final String Function(int index, String label) semanticLabel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: BullSpacing.md,
      vertical: BullSpacing.xs,
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        var labelWidth = 0.0;
        for (final label in labels) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: context.bullType.label),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          labelWidth += painter.width;
          painter.dispose();
        }
        final markerWidth = labels.length * (BullSpacing.lg + BullSpacing.xxs);
        final connectorSpace = (labels.length - 1) * BullSpacing.md;
        final wrapLabels =
            labelWidth + markerWidth + connectorSpace > constraints.maxWidth;
        return Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(
                      horizontal: BullSpacing.xs,
                    ),
                    color: context.bull.border,
                  ),
                ),
              Flexible(
                flex: wrapLabels ? 4 : 0,
                child: Semantics(
                  label: semanticLabel(i, labels[i]),
                  selected: i == currentStep,
                  excludeSemantics: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: BullSpacing.lg,
                        height: BullSpacing.lg,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < currentStep
                              ? context.bull.secondary
                              : i == currentStep
                              ? context.bull.primary
                              : context.bull.transparent,
                          border: i > currentStep
                              ? Border.all(color: context.bull.border)
                              : null,
                        ),
                        child: i < currentStep
                            ? Icon(
                                Icons.check,
                                size: BullSpacing.md,
                                color: context.bull.onSecondary,
                              )
                            : Text(
                                '${i + 1}',
                                style: context.bullType.caption.copyWith(
                                  color: i == currentStep
                                      ? context.bull.onPrimary
                                      : context.bull.textMuted,
                                ),
                              ),
                      ),
                      const SizedBox(width: BullSpacing.xxs),
                      Flexible(
                        child: Text(
                          labels[i],
                          style: context.bullType.label.copyWith(
                            color: i <= currentStep
                                ? context.bull.text
                                : context.bull.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}
