import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RecoverWalletButton extends StatelessWidget {
  const RecoverWalletButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.big(
      label: 'Recover Wallet',
      bgColor: Colors.transparent,
      textColor: context.colour.onPrimary,
      iconData: Icons.history_edu,
      outlined: true,
      onPressed: () {
        context.goNamed(OnboardingRoute.recoverOptions.name);
      },
    );
  }
}
