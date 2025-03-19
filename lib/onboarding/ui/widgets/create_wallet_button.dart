import 'package:bb_mobile/_ui/components/buttons/button.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CreateWalletButton extends StatelessWidget {
  const CreateWalletButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final creating =
        context.select((OnboardingBloc bloc) => bloc.state.creatingOnSplash());

    return BBButton.big(
      label: 'Create New Wallet',
      bgColor: context.colour.secondary,
      textColor: context.colour.onPrimary,
      iconData: Icons.account_balance_wallet_outlined,
      onPressed: () {
        if (creating) return;
        context.read<OnboardingBloc>().add(const OnboardingCreateNewWallet());
      },
    );
  }
}
