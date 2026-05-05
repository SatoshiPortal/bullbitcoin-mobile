import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/wizard/wizard_gate.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RecoverWalletButton extends StatefulWidget {
  const RecoverWalletButton({super.key});

  @override
  State<RecoverWalletButton> createState() => _RecoverWalletButtonState();
}

class _RecoverWalletButtonState extends State<RecoverWalletButton> {
  // Sync guard mirroring `CreateWalletButton._pushing` — covers the
  // rapid-tap window between the tap and the wizard route mounting,
  // before any bloc loading state would otherwise gate further taps.
  bool _pushing = false;

  @override
  Widget build(BuildContext context) {
    return BBButton.big(
      label: context.loc.onboardingRecoverWalletButton,
      bgColor: context.appColors.transparent,
      textColor: context.appColors.onPrimaryFixed,
      iconData: Icons.history_edu,
      outlined: true,
      disabled: _pushing,
      onPressed: () async {
        if (_pushing) return;
        // Same wizard gate as `CreateWalletButton` — fresh-install path
        // routes through the wizard before the recovery flow proper.
        if (await WizardGate.shouldShow()) {
          if (!mounted) return;
          setState(() => _pushing = true);
          await context.pushNamed(WizardRoute.wizard.name);
          if (!mounted) return;
          setState(() => _pushing = false);
        }
        if (!mounted) return;
        context.goNamed(OnboardingRoute.recoverOptions.name);
      },
    );
  }
}
