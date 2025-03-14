import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/onboarding/ui/screens/onboarding_recovery.dart';
import 'package:bb_mobile/onboarding/ui/screens/onboarding_recovery_success.dart';
import 'package:bb_mobile/onboarding/ui/screens/onboarding_splash.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: locator<OnboardingBloc>(),
      child: BlocListener<OnboardingBloc, OnboardingState>(
        listenWhen: (previous, current) =>
            previous.creating != current.creating &&
            current.step == OnboardingStep.createSucess,
        listener: (context, state) {
          context.goNamed(AppRoute.home.name);
        },
        child: _Screen(loading: loading),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SelectScreen(loading: loading),
    );
  }
}

class SelectScreen extends StatelessWidget {
  const SelectScreen({
    super.key,
    required this.loading,
  });

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final step = context.select((OnboardingBloc _) => _.state.step);

    return switch (step) {
      OnboardingStep.splash ||
      OnboardingStep.createSucess =>
        OnboardingSplash(loading: loading),
      OnboardingStep.recoveryWords => const OnboardingRecovery(),
      OnboardingStep.recoverySuccess => const OnboardingRecoverySuccess(),
    };
  }
}
