import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/wizard/ui/wizard_router.dart';
import 'package:bb_mobile/features/wizard/wizard_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CreateWalletButton extends StatefulWidget {
  const CreateWalletButton({super.key});

  @override
  State<CreateWalletButton> createState() => _CreateWalletButtonState();
}

class _CreateWalletButtonState extends State<CreateWalletButton> {
  // Sync guard for the window between the user's tap and the wizard
  // route actually mounting. Without this, a rapid double-tap would
  // push two wizard routes onto the stack before the bloc sees any
  // loading state. The `creating` bloc flag is reactive and lags by
  // a frame, so we cover both windows.
  bool _pushing = false;

  @override
  Widget build(BuildContext context) {
    final creating = context.select(
      (OnboardingBloc bloc) =>
          bloc.state.onboardingStepStatus == OnboardingStepStatus.loading &&
          bloc.state.step == OnboardingStep.create,
    );

    return BBButton.big(
      label: context.loc.onboardingCreateNewWallet,
      bgColor: context.appColors.secondaryFixed,
      textColor: context.appColors.onSecondaryFixed,
      iconData: Icons.account_balance_wallet_outlined,
      // Visually + functionally disable the button the moment the bloc
      // emits loading OR the wizard route is being pushed. Together
      // with the bloc-level early-return guard and the use-case
      // idempotency check, this closes the rapid-tap race that
      // produced duplicate default wallets (#2015).
      disabled: creating || _pushing,
      onPressed: () async {
        if (creating || _pushing) return;
        if (await WizardGate.shouldShow()) {
          if (!mounted) return;
          setState(() => _pushing = true);
          // The wizard pops with `true` on completion (Skip / Get
          // Started) and `null` on a back-gesture cancel — abort the
          // create flow in the latter case so the user lands back on
          // the splash without a wallet being silently generated.
          final completed = await context.pushNamed<bool>(
            WizardRoute.wizard.name,
          );
          if (!mounted) return;
          setState(() => _pushing = false);
          if (completed != true) return;
        }
        if (!mounted) return;
        context.read<OnboardingBloc>().add(const OnboardingCreateNewWallet());
      },
    );
  }
}
