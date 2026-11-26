import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_l10n.dart';

enum ArkExitStepState { done, current, upcoming }

class ArkExitStep {
  final String title;
  final String detail;
  final ArkExitStepState state;

  const ArkExitStep({
    required this.title,
    required this.detail,
    required this.state,
  });
}

/// Vertical timeline of an exit's observed stages. Every stage exposes its
/// state in the semantics label, not only through colour.
class ArkExitSteps extends StatelessWidget {
  final List<ArkExitStep> steps;

  const ArkExitSteps({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final colors = context.bull;
    return Container(
      padding: const EdgeInsets.all(BullSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.bullShapes.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, step) in steps.indexed)
            Semantics(
              container: true,
              label:
                  '${step.title}, ${switch (step.state) {
                    ArkExitStepState.done => l10n.exitStepDoneSemantics,
                    ArkExitStepState.current => l10n.exitStepCurrentSemantics,
                    ArkExitStepState.upcoming => l10n.exitStepUpcomingSemantics,
                  }}. ${step.detail}',
              excludeSemantics: true,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: BullSpacing.lg,
                      child: Column(
                        children: [
                          _Marker(state: step.state),
                          if (index < steps.length - 1)
                            Expanded(
                              child: Container(
                                width: 2,
                                margin: const EdgeInsets.symmetric(
                                  vertical: BullSpacing.xxs,
                                ),
                                color: step.state == ArkExitStepState.done
                                    ? colors.success
                                    : colors.outlineVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Gap(BullSpacing.sm),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: index < steps.length - 1
                              ? BullSpacing.md
                              : BullSpacing.zero,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BullText(
                              step.title,
                              role: BullTextRole.body,
                              fontWeight: FontWeight.w600,
                              color: step.state == ArkExitStepState.upcoming
                                  ? colors.textMuted
                                  : colors.text,
                            ),
                            const Gap(BullSpacing.xxs),
                            BullText(
                              step.detail,
                              role: BullTextRole.caption,
                              color: colors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  final ArkExitStepState state;

  const _Marker({required this.state});

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return switch (state) {
      ArkExitStepState.done => Container(
        width: BullSpacing.lg,
        height: BullSpacing.lg,
        decoration: BoxDecoration(
          color: colors.success,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: BullIcon(BullIcons.check, size: 16, color: colors.onPrimary),
        ),
      ),
      ArkExitStepState.current => Container(
        width: BullSpacing.lg,
        height: BullSpacing.lg,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.primary, width: 2),
        ),
        child: Center(
          child: Container(
            width: BullSpacing.xs,
            height: BullSpacing.xs,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
      ArkExitStepState.upcoming => Container(
        width: BullSpacing.lg,
        height: BullSpacing.lg,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.outlineVariant, width: 2),
        ),
      ),
    };
  }
}
