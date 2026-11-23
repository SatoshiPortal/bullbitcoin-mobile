import 'package:bull_ui/app_theme.dart';
import 'package:wizard/src/wizard_localizations_context.dart';
import 'package:wizard/src/ui/wizard_page.dart';
import 'package:wizard/src/ui/widgets/wizard_step_layout.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart' show BullText, BullTypographyX;

/// Mission / consent page body — text only. The Yes/No choice is
/// rendered by [WizardScreen] in the bottom chrome (in place of the
/// dots + Next button) so the user must answer to advance.
class MissionStep extends StatelessWidget {
  const MissionStep({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final bodyStyle = context.bullType.body.copyWith(
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
          BullText(loc.wizardMissionBody1, style: bodyStyle),
          SizedBox(height: vGapMd),
          BullText(loc.wizardMissionBody2, style: bodyStyle),
          SizedBox(height: vGapLg),
          BullText(
            loc.wizardMissionQuestion,
            style: context.bullType.body
                .copyWith(fontWeight: FontWeight.w500)
                .copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.appColors.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}
