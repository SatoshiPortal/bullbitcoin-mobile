import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/wizard/ui/wizard_page.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_step_layout.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart' show BullText, BullTypographyX;

class JourneyStep extends StatelessWidget {
  const JourneyStep({super.key});

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
    final vGap = Device.screen.height * 0.02;
    return WizardStepLayout(
      page: WizardPage.journey,
      title: loc.wizardJourneyTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BullText(
            loc.wizardJourneyBody,
            style: context.bullType.body.copyWith(
              color: context.appColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          SizedBox(height: vGap),
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
    final hGap = Device.screen.width * 0.03;
    final vPad = Device.screen.height * 0.012;
    return Padding(
      padding: EdgeInsets.only(bottom: vPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2, right: hGap),
            child: Icon(
              Icons.arrow_forward,
              size: 18,
              color: context.appColors.primary,
            ),
          ),
          Expanded(
            child: BullText(
              text,
              style: context.bullType.body.copyWith(
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
