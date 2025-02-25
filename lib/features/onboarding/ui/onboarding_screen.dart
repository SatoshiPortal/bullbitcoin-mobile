import 'package:bb_mobile/features/app_startup/app_locator.dart';
import 'package:bb_mobile/features/app_startup/app_router.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/onboarding/ui/widgets/create_wallet_button.dart';
import 'package:bb_mobile/utils/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (BuildContext context) => locator<OnboardingBloc>(),
      child: BlocListener<OnboardingBloc, OnboardingState>(
        listenWhen: (previous, current) => current is OnboardingSuccess,
        listener: (context, state) {
          // If onboarding was successful, navigate to the home screen
          context.goNamed(AppRoute.home.name);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.loc.onboardingScreenTitle),
            actions: [
              IconButton(
                onPressed: () {
                  context.pushNamed(AppRoute.settings.name);
                },
                icon: const Icon(Icons.settings),
              ),
            ],
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CreateWalletButton(),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () async {
                    context.pushNamed(AppRoute.recoverWallet.name);
                  },
                  child: Text(context.loc.onboardingRecoverWalletButtonLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
