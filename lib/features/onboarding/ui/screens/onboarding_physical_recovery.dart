import 'dart:async';

import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/core/widgets/wallet_birthday_picker.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/onboarding/ui/widgets/app_bar.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
          listenWhen: (previous, current) =>
              previous.step != current.step ||
              previous.onboardingStepStatus != current.onboardingStepStatus ||
              previous.needsBitcoinBirthdaySelection !=
                  current.needsBitcoinBirthdaySelection,
          listener: (context, state) async {
            if (state.step == OnboardingStep.recover &&
                state.onboardingStepStatus == OnboardingStepStatus.success) {
              // Lands on the dedicated CBF sync screen instead of wallet
              // home when the recovered default Bitcoin wallet opted into
              // compact block filters; every other wallet keeps this exact
              // navigation — see that helper.
              unawaited(
                WalletRouter.goToWalletHomeOrInitialSyncForDefaultBitcoinWallet(
                  context,
                  isRecoveryOrImport: true,
                ),
              );
              return;
            }

            if (state.needsBitcoinBirthdaySelection) {
              final bloc = context.read<OnboardingBloc>();
              final checkpoint = await WalletBirthdayPicker.show(
                context,
                isTestnet: state.pendingRecoveryIsTestnet,
                onResolve: bloc.resolveBitcoinBirthdayCheckpoint,
              );
              if (!context.mounted) return;
              bloc.add(
                OnboardingBitcoinBirthdayResolved(checkpoint: checkpoint),
              );
            }
          },
          child: BlocBuilder<OnboardingBloc, OnboardingState>(
            builder: (context, state) {
              return Scaffold(
                appBar: const OnboardingAppBar(),
                body: Column(
                  children: [
                    FadingLinearProgress(
                      trigger:
                          state.onboardingStepStatus ==
                          OnboardingStepStatus.loading,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      height: 2.0,
                    ),
                    Expanded(
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: .stretch,
                              children: [
                                IgnorePointer(
                                  ignoring:
                                      state.onboardingStepStatus ==
                                      OnboardingStepStatus.loading,
                                  child: Opacity(
                                    opacity:
                                        state.onboardingStepStatus ==
                                            OnboardingStepStatus.loading
                                        ? 0.5
                                        : 1.0,
                                    child: MnemonicWidget(
                                      initialLength:
                                          bip39.MnemonicLength.words12,
                                      allowMultipleMnemonicLength: true,
                                      allowLabel: false,
                                      allowPassphrase: false,
                                      submitLabel:
                                          context.loc.onboardingRecover,
                                      onSubmit: (mnemonic) {
                                        context.read<OnboardingBloc>().add(
                                          OnboardingRecoverWalletClicked(
                                            mnemonic: mnemonic,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
