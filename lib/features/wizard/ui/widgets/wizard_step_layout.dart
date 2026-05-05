import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Common scaffold for the body of one wizard PageView page. Renders the
/// red "PAGE x / total" eyebrow + bold uppercase title, then the page's
/// content in a scrollable area so longer copy never clips.
class WizardStepLayout extends StatelessWidget {
  const WizardStepLayout({
    super.key,
    required this.stepIndex,
    required this.totalSteps,
    required this.title,
    required this.child,
  });

  final int stepIndex;
  final int totalSteps;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hPad = Device.screen.width * 0.06;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.loc.wizardPageIndicator(stepIndex + 1, totalSteps),
            style: context.font.labelMedium?.copyWith(
              color: context.appColors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const Gap(8),
          Text(
            title.toUpperCase(),
            style: context.font.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: context.appColors.onSurface,
              height: 1.05,
            ),
          ),
          const Gap(20),
          child,
        ],
      ),
    );
  }
}
