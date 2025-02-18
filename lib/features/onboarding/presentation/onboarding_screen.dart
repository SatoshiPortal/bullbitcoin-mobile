import 'package:bb_mobile/app_locator.dart';
import 'package:bb_mobile/app_router.dart';
import 'package:bb_mobile/build_context_x.dart';
import 'package:bb_mobile/features/home/home_router.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/onboarding/presentation/widgets/create_wallet_button.dart';
import 'package:bb_mobile/features/recover_wallet/recover_wallet_router.dart';
import 'package:bb_mobile/features/settings/settings_router.dart';
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
          GoRouter.of(context).goNamed(HomeRoute.home.name);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.loc.onboardingScreenTitle),
            actions: [
              IconButton(
                onPressed: () {
                  GoRouter.of(context).pushNamed(SettingsRoute.settings.name);
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
                    GoRouter.of(context)
                        .pushNamed(RecoverWalletRoute.recoverWallet.name);
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
