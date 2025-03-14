import 'package:bb_mobile/_ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OnboardingAppBar extends StatelessWidget implements PreferredSizeWidget {
  const OnboardingAppBar();

  @override
  Widget build(BuildContext context) {
    final isRecoverStep = context.select(
      (OnboardingBloc _) => _.state.step == OnboardingStep.recoveryWords,
    );

    if (!isRecoverStep) return const SizedBox.shrink();

    return AppBar(
      flexibleSpace: TopBar(
        title: 'Recover Wallet',
        onBack: () {
          context.read<OnboardingBloc>().add(const OnboardingGoBack());
        },
      ),
      automaticallyImplyLeading: false,
      forceMaterialTransparency: true,
    );
  }

  @override
  Size get preferredSize => const Size(double.maxFinite, kToolbarHeight);
}
