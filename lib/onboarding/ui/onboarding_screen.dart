import 'package:bb_mobile/_ui/components/buttons/button.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/gen/assets.gen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/onboarding/ui/widgets/create_wallet_button.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: locator<OnboardingBloc>(),
      child: BlocListener<OnboardingBloc, OnboardingState>(
        listenWhen: (previous, current) => current is OnboardingSuccess,
        listener: (context, state) {
          // If onboarding was successful, navigate to the home screen
          if (state is OnboardingSuccess) {
            // Using AppRouter directly instead of context
            context.goNamed(AppRoute.home.name);
          }
        },
        child: _Screen(loading: loading),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({
    super.key,
    required this.loading,
  });

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _BG(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Spacer(),
                Image.asset(
                  Assets.images2.whitebullwithtext.path,
                  height: 127,
                ),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 40,
                  ),
                  child: _Actions(loading: loading),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    super.key,
    required this.loading,
  });

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isCreationInProgress = context.select(
      (OnboardingBloc bloc) => bloc.state.maybeMap(
        walletCreationInProgress: (_) => true,
        orElse: () => false,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading || isCreationInProgress)
          Center(
            child: CircularProgressIndicator(
              color: context.colour.onPrimary,
            ),
          )
        else ...[
          const CreateWalletButton(),
          const Gap(10),
          BBButton.big(
            label: 'Recover Wallet Backup',
            bgColor: Colors.transparent,
            textColor: context.colour.onPrimary,
            iconData: Icons.history_edu,
            outlined: true,
            onPressed: () async {
              context.pushNamed(AppRoute.recoverWallet.name);
            },
          ),
        ],
      ],
    );
  }
}

class _BG extends StatelessWidget {
  const _BG();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: context.colour.primary,
          height: double.infinity,
          width: double.infinity,
        ),
        Opacity(
          opacity: 0.1,
          child: Image.asset(
            Assets.images2.bgLong.path,
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
          ),
        ),
      ],
    );
  }
}
