import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_step_layout.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({
    super.key,
    required this.stepIndex,
    required this.totalSteps,
  });

  final int stepIndex;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final bodyStyle = context.font.bodyMedium?.copyWith(
      color: context.appColors.onSurfaceVariant,
      height: 1.4,
    );
    return WizardStepLayout(
      stepIndex: stepIndex,
      totalSteps: totalSteps,
      title: loc.wizardWelcomeTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.wizardWelcomeBody1, style: bodyStyle),
          const Gap(12),
          Text(loc.wizardWelcomeBody2, style: bodyStyle),
          const Gap(16),
          Text(
            loc.wizardWelcomeUseCasesHeader,
            style: context.font.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.appColors.onSurface,
            ),
          ),
          const Gap(8),
          _Bullet(text: loc.wizardWelcomeUseCase1),
          _Bullet(text: loc.wizardWelcomeUseCase2),
          _Bullet(text: loc.wizardWelcomeUseCase3),
          const Gap(16),
          InfoCard(
            title: loc.wizardWelcomeImportantTitle,
            description: loc.wizardWelcomeImportantBody,
            tagColor: context.appColors.error,
            bgColor: context.appColors.errorContainer,
          ),
          const Gap(20),
          Text(
            loc.wizardWelcomeFooter,
            style: bodyStyle?.copyWith(color: context.appColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: context.appColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
