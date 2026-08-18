import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';

class CreateWalletButton extends StatelessWidget {
  const CreateWalletButton({super.key});

  @override
  Widget build(BuildContext context) {
    final creating = context.select(
      (OnboardingBloc bloc) =>
          bloc.state.onboardingStepStatus == OnboardingStepStatus.loading &&
          bloc.state.step == OnboardingStep.create,
    );

    return BullButton.primary(
      label: context.loc.onboardingCreateNewWallet,
      iconData: Icons.account_balance_wallet_outlined,
      // Visually + functionally disable the button the moment the bloc
      // emits loading. Combined with the bloc-level early-return guard
      // and the use-case idempotency check, closes the rapid-tap race
      // that produced duplicate default wallets (#2015).
      disabled: creating,
      onPressed: () {
        if (creating) return;
        context.read<OnboardingBloc>().add(const OnboardingCreateNewWallet());
      },
    );
  }
}
