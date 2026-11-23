import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullText, BullTypography, Gap, BullTypographyX;

/// Page 1 of the wizard — splash-style welcome that mirrors
/// `OnboardingSplash` visually. Renders only the centered content; the
/// red + patterned background is painted behind the whole `Scaffold`
/// body by `WizardScreen` so it extends under the dots + Next button.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Spacer(flex: 2),
          Image.asset(Assets.logos.bbLogoWhite.path, height: 127),
          const Gap(36),
          BullText(
            context.loc.onboardingBullBitcoin,
            style: TextStyle(
              fontFamily: BullTypography.brandFamily,
              fontSize: 54, // Brand wordmark: a layout size, not a role (bull-ui-check allowlist).
              fontWeight: FontWeight.w500,
              color: context.appColors.onPrimaryFixed,
              height: 1,
            ),
          ),
          BullText(
            context.loc.onboardingOwnYourMoney,
            style: TextStyle(
              fontFamily: BullTypography.brandFamily,
              fontSize: 40, // Brand wordmark: a layout size, not a role (bull-ui-check allowlist).
              fontWeight: FontWeight.w500,
              color: context.appColors.secondaryFixed,
              height: 1,
            ),
          ),
          const Gap(10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: BullText(
              context.loc.onboardingSplashDescription,
              style: context.bullType.caption,
              color: context.appColors.onPrimaryFixed,
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
