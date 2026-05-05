import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_step_layout.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class JourneyStep extends StatelessWidget {
  const JourneyStep({
    super.key,
    required this.stepIndex,
    required this.totalSteps,
  });

  final int stepIndex;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final tips = <String>[
      loc.wizardJourneyTip1,
      loc.wizardJourneyTip2,
      loc.wizardJourneyTip3,
      loc.wizardJourneyTip4,
      loc.wizardJourneyTip5,
      loc.wizardJourneyTip6,
      loc.wizardJourneyTip7,
      loc.wizardJourneyTip8,
    ];
    return WizardStepLayout(
      stepIndex: stepIndex,
      totalSteps: totalSteps,
      title: loc.wizardJourneyTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.wizardJourneyBody,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const Gap(16),
          for (final tip in tips) _Tip(text: tip),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 12),
            child: Icon(
              Icons.arrow_forward,
              size: 18,
              color: context.appColors.primary,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
