import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/wizard/ui/wizard_page.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_step_layout.dart';
import 'package:flutter/material.dart';

/// Mission / consent page body — text only. The Yes/No choice is
/// rendered by [WizardScreen] in the bottom chrome (in place of the
/// dots + Next button) so the user must answer to advance.
class MissionStep extends StatelessWidget {
  const MissionStep({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final bodyStyle = context.font.bodyMedium?.copyWith(
      color: context.appColors.onSurfaceVariant,
      height: 1.4,
    );
    final vGapMd = Device.screen.height * 0.018;
    final vGapLg = Device.screen.height * 0.025;
    return WizardStepLayout(
      page: WizardPage.mission,
      title: loc.wizardMissionTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(loc.wizardMissionBody1, style: bodyStyle),
          SizedBox(height: vGapMd),
          BBText(loc.wizardMissionBody2, style: bodyStyle),
          SizedBox(height: vGapLg),
          BBText(
            loc.wizardMissionQuestion,
            style: context.font.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.appColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
