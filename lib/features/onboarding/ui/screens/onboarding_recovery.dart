import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/onboarding/ui/widgets/app_bar.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/inputs/seed_word.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class OnboardingRecovery extends StatelessWidget {
  const OnboardingRecovery({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: OnboardingAppBar(),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Gap(40),
                  _WordGrid(),
                  Gap(80),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Button(),
                SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WordGrid extends StatelessWidget {
  const _WordGrid();

  @override
  Widget build(BuildContext context) {
    final hintWords = context.select((OnboardingBloc _) => _.state.hintWords);
    final validWords = context.select((OnboardingBloc _) => _.state.validWords);
    return SeedWordsGrid(
      wordCount: 12,
      validWords: validWords,
      hintWords: hintWords,
      onWordChanged: (_) {
        context.read<OnboardingBloc>().add(
              OnboardingRecoveryWordChanged(
                index: _.index,
                word: _.word,
              ),
            );
      },
    );
  }
}

class _Button extends StatelessWidget {
  const _Button();

  @override
  Widget build(BuildContext context) {
    final hasAllValidWords =
        context.select((OnboardingBloc _) => _.state.hasAllValidWords());

    final creating = context.select(
      (OnboardingBloc _) => _.state.creating,
    );

    if (creating) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BBButton.big(
        label: 'Recover',
        onPressed: () {
          if (hasAllValidWords) {
            context
                .read<OnboardingBloc>()
                .add(const OnboardingRecoverWalletClicked());
          }
        },
        bgColor: context.colour.secondary,
        textColor: context.colour.onPrimary,
      ),
    );
  }
}
