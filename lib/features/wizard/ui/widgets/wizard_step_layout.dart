import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/wizard/ui/wizard_page.dart';
import 'package:flutter/material.dart';

/// Common scaffold for the body of one wizard PageView page. Renders the
/// red "PAGE x / total" eyebrow + bold uppercase title, then the page's
/// content in a scrollable area so longer copy never clips.
class WizardStepLayout extends StatelessWidget {
  const WizardStepLayout({
    super.key,
    required this.page,
    required this.title,
    required this.child,
  });

  final WizardPage page;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hPad = Device.screen.width * 0.06;
    final vGapSm = Device.screen.height * 0.01;
    final vGapMd = Device.screen.height * 0.025;
    // Bottom padding clears the floating chrome (dots + Next button OR
    // Yes/No row) overlaid by `WizardScreen` so the last item is fully
    // visible at max-scroll instead of being hidden behind the chrome.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, kWizardChromeHeight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            context.loc.wizardPageIndicator(page.number, WizardPage.total),
            style: context.font.labelMedium?.copyWith(
              color: context.appColors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: vGapSm),
          BBText(
            title.toUpperCase(),
            style: context.font.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: context.appColors.onSurface,
              height: 1.05,
            ),
          ),
          SizedBox(height: vGapMd),
          child,
        ],
      ),
    );
  }
}
