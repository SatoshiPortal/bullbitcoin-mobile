import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CreateWalletButton extends StatelessWidget {
  const CreateWalletButton({super.key});

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
      // emits loading. Combined with the bloc-level early-return guard
      // and the use-case idempotency check, closes the rapid-tap race
      // that produced duplicate default wallets (#2015).
      disabled: creating,
      onPressed: () {
        if (creating) return;
        // Wallet creation goes through the entropy ceremony: the ceremony
        // screen dispatches OnboardingCreateNewWallet once its bar fills.
        context.pushNamed(OnboardingRoute.entropyCeremony.name);
      },
    );
  }
}
