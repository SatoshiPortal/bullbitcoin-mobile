import 'package:bb_mobile/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/onboarding/ui/widgets/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.body,
  });

  final Widget body;

  @override
  Widget build(BuildContext context) {
    final isRecoverStep = context.select(
      (OnboardingBloc _) => _.state.step == OnboardingStep.recoveryWords,
    );
    return Scaffold(
      appBar: isRecoverStep ? const OnboardingAppBar() : null,
      body: body,
    );
  }
}
