import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/themes/fonts.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

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
          BBText(
            context.loc.onboardingBullBitcoin,
            style: AppFonts.textTitleTheme.textStyle.copyWith(
              fontSize: 54,
              fontWeight: FontWeight.w500,
              color: context.appColors.onPrimaryFixed,
              height: 1,
            ),
          ),
          BBText(
            context.loc.onboardingOwnYourMoney,
            style: AppFonts.textTitleTheme.textStyle.copyWith(
              fontSize: 40,
              fontWeight: FontWeight.w500,
              color: context.appColors.secondaryFixed,
              height: 1,
            ),
          ),
          const Gap(10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: BBText(
              context.loc.onboardingSplashDescription,
              style: context.font.labelSmall,
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
