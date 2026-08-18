import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class RecoverWalletButton extends StatelessWidget {
  const RecoverWalletButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BullButton.secondary(
      label: context.loc.onboardingRecoverWalletButton,
      iconData: Icons.history_edu,
      onPressed: () => context.goNamed(OnboardingRoute.recoverOptions.name),
    );
  }
}
