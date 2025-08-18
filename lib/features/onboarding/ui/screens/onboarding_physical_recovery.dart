import 'dart:async';

import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/onboarding/ui/widgets/app_bar.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class OnboardingPhysicalRecovery extends StatefulWidget {
  const OnboardingPhysicalRecovery({super.key});

  @override
  State<OnboardingPhysicalRecovery> createState() =>
      _OnboardingPhysicalRecoveryState();
}

class _OnboardingPhysicalRecoveryState extends State<OnboardingPhysicalRecovery>
    with PrivacyScreen {
  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: enableScreenPrivacy(),
      builder: (context, snapshot) {
        return BlocListener<OnboardingBloc, OnboardingState>(
          listenWhen:
              (previous, current) =>
                  previous.step != current.step ||
                  previous.onboardingStepStatus != current.onboardingStepStatus,
          listener: (context, state) {
            if (state.step == OnboardingStep.recover &&
                state.onboardingStepStatus == OnboardingStepStatus.success) {
              context.goNamed(WalletRoute.walletHome.name);
            }
          },
          child: Scaffold(
            appBar: const OnboardingAppBar(),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MnemonicWidget(
                        initialLength: bip39.MnemonicLength.words12,
                        allowMultipleMnemonicLength: false,
                        allowLabel: false,
                        allowPassphrase: false,
                        submitLabel: 'Recover',
                        onSubmit: (mnemonic) {
                          context.read<OnboardingBloc>().add(
                            OnboardingRecoverWalletClicked(mnemonic: mnemonic),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
