import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton;

class RecoverWalletButton extends StatelessWidget {
  const RecoverWalletButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BullButton.big(
      label: context.loc.onboardingRecoverWalletButton,
      bgColor: context.appColors.transparent,
      textColor: context.appColors.onPrimaryFixed,
      iconData: Icons.history_edu,
      outlined: true,
      onPressed: () => context.goNamed(OnboardingRoute.recoverOptions.name),
    );
  }
}
