import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/core/router/app_router.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/onboarding/presentation/widgets/create_wallet_button.dart';
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
          GoRouter.of(context).goNamed(AppRoute.home.name);
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Onboarding Screen'),
            actions: [
              IconButton(
                onPressed: () {
                  GoRouter.of(context).pushNamed(AppRoute.settings.name);
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
                  onPressed: () {
                    GoRouter.of(context).pushNamed(AppRoute.recoverWallet.name);
                  },
                  child: const Text('Recover Wallet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
