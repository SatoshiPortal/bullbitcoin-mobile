import 'package:bb_mobile/_core/utils/build_context_x.dart';
import 'package:bb_mobile/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CreateWalletButton extends StatelessWidget {
  const CreateWalletButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isCreationInProgress = context.select(
      (OnboardingBloc bloc) => bloc.state.maybeMap(
        walletCreationInProgress: (_) => true,
        orElse: () => false,
      ),
    );

    return ElevatedButton(
      onPressed: isCreationInProgress
          ? null
          : () => context
              .read<OnboardingBloc>()
              .add(const OnboardingWalletCreated()),
      child: isCreationInProgress
          ? const CircularProgressIndicator()
          : Text(context.loc.onboardingCreateWalletButtonLabel),
    );
  }
}
