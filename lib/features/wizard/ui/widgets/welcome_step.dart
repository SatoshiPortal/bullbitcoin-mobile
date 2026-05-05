import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_step_layout.dart';
import 'package:flutter/material.dart';

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
    final vGapSm = Device.screen.height * 0.01;
    final vGapMd = Device.screen.height * 0.018;
    final vGapLg = Device.screen.height * 0.025;
    return WizardStepLayout(
      stepIndex: stepIndex,
      totalSteps: totalSteps,
      title: loc.wizardWelcomeTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.wizardWelcomeBody1, style: bodyStyle),
          SizedBox(height: vGapMd),
          Text(loc.wizardWelcomeBody2, style: bodyStyle),
          SizedBox(height: vGapLg),
          Text(
            loc.wizardWelcomeUseCasesHeader,
            style: context.font.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.appColors.onSurface,
            ),
          ),
          SizedBox(height: vGapSm),
          _Bullet(text: loc.wizardWelcomeUseCase1),
          _Bullet(text: loc.wizardWelcomeUseCase2),
          _Bullet(text: loc.wizardWelcomeUseCase3),
          SizedBox(height: vGapLg),
          InfoCard(
            title: loc.wizardWelcomeImportantTitle,
            description: loc.wizardWelcomeImportantBody,
            tagColor: context.appColors.error,
            bgColor: context.appColors.errorContainer,
          ),
          SizedBox(height: vGapLg),
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
    final hGap = Device.screen.width * 0.025;
    final vPad = Device.screen.height * 0.008;
    return Padding(
      padding: EdgeInsets.only(bottom: vPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 6, right: hGap),
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
