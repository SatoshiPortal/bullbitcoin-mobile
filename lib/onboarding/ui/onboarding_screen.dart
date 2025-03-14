import 'package:bb_mobile/_core/domain/usecases/find_mnemonic_words_use_case.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/onboarding/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/onboarding/ui/screens/onboarding_recovery.dart';
import 'package:bb_mobile/onboarding/ui/screens/onboarding_recovery_success.dart';
import 'package:bb_mobile/onboarding/ui/screens/onboarding_splash.dart';
import 'package:bb_mobile/onboarding/ui/widgets/app_bar.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.loading = false});

  final bool loading;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final OnboardingBloc _bloc;

  @override
  void initState() {
    _bloc = OnboardingBloc(
      createDefaultWalletsUseCase: locator<CreateDefaultWalletsUseCase>(),
      findMnemonicWordsUseCase: locator<FindMnemonicWordsUseCase>(),
      initLoading: widget.loading,
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocListener<OnboardingBloc, OnboardingState>(
        listenWhen: (previous, current) =>
            previous.creating != current.creating &&
            current.step == OnboardingStep.createSucess,
        listener: (context, state) {
          context.goNamed(AppRoute.home.name);
        },
        child: const Scaffold(
          appBar: OnboardingAppBar(),
          body: OnboardingFlow(),
        ),
      ),
    );
  }
}

class OnboardingFlow extends StatelessWidget {
  const OnboardingFlow({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final step = context.select((OnboardingBloc _) => _.state.step);

    return switch (step) {
      OnboardingStep.splash ||
      OnboardingStep.createSucess =>
        const OnboardingSplash(),
      OnboardingStep.recoveryWords => const OnboardingRecovery(),
      OnboardingStep.recoverySuccess => const OnboardingRecoverySuccess(),
    };
  }
}
