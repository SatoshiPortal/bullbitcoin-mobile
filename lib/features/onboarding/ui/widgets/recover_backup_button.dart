import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/buttons/button.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RecoverWalletButton extends StatelessWidget {
  const RecoverWalletButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.big(
      label: context.loc.onboardingRecoverWalletButton,
      bgColor: context.appColors.transparent,
      textColor: context.appColors.onPrimaryFixed,
      iconData: Icons.history_edu,
      outlined: true,
      onPressed: () {
        context.goNamed(OnboardingRoute.recoverOptions.name);
      },
    );
  }
}
