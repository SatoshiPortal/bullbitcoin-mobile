import 'dart:async';

import 'package:screen_privacy/screen_privacy.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/import_mnemonic/public/import_mnemonic_facade.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/onboarding/ui/widgets/app_bar.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ui/bull_ui.dart' show BullFadingLinearProgress;

class OnboardingPhysicalRecovery extends StatefulWidget {
  const OnboardingPhysicalRecovery({super.key});

  @override
  State<OnboardingPhysicalRecovery> createState() =>
      _OnboardingPhysicalRecoveryState();
}

class _OnboardingPhysicalRecoveryState extends State<OnboardingPhysicalRecovery>
    with PrivacyScreen, WidgetsBindingObserver {
  late final Future<void> _privacyFuture = enableScreenPrivacy();
  bool _scanning = false;
  bool _dialogOpen = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _attempt++;
      if (_scanning) setState(() => _scanning = false);
      if (_dialogOpen) {
        _dialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop(false);
      }
    }
  }

  Future<void> _submit(Mnemonic mnemonic) async {
    if (_scanning) return;
    final attempt = ++_attempt;
    while (true) {
      setState(() => _scanning = true);
      final scan = await context.read<OnboardingBloc>().scanWallet(
        words: mnemonic.words,
        passphrase: mnemonic.passphrase,
      );
      if (!mounted || attempt != _attempt) return;
      setState(() => _scanning = false);
      if (scan is Err) {
        _dialogOpen = true;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.loc.onboardingScanUnavailableTitle),
            content: Text(context.loc.onboardingScanUnavailableMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.loc.retry),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.loc.onboardingContinueWithoutChecking),
              ),
            ],
          ),
        );
        _dialogOpen = false;
        if (!mounted || attempt != _attempt || proceed == null) return;
        if (proceed) break;
        continue;
      }
      final hasHistory = (scan as Ok<bool, OnboardingFailure>).value;
      if (!hasHistory) {
        _dialogOpen = true;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.loc.emptyWalletTitle),
            content: Text(
              '${context.loc.emptyWalletMessage}\n\n${context.loc.emptyWalletBitcoinOnly}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.loc.correct),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.loc.continueButton),
              ),
            ],
          ),
        );
        _dialogOpen = false;
        if (!mounted || attempt != _attempt || proceed != true) return;
      }
      break;
    }
    context.read<OnboardingBloc>().add(
      OnboardingRecoverWalletClicked(mnemonic: mnemonic),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _privacyFuture,
      builder: (context, snapshot) {
        return BlocListener<OnboardingBloc, OnboardingState>(
          listenWhen: (previous, current) =>
              previous.step != current.step ||
              previous.onboardingStepStatus != current.onboardingStepStatus,
          listener: (context, state) {
            if (state.step == OnboardingStep.recover &&
                state.onboardingStepStatus == OnboardingStepStatus.success) {
              context.goNamed(WalletRoute.walletHome.name);
            }
          },
          child: BlocBuilder<OnboardingBloc, OnboardingState>(
            builder: (context, state) {
              return Scaffold(
                appBar: const OnboardingAppBar(),
                body: Column(
                  children: [
                    BullFadingLinearProgress(
                      trigger:
                          _scanning ||
                          state.onboardingStepStatus ==
                              OnboardingStepStatus.loading,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      height: 2.0,
                    ),
                    Expanded(
                      child: SafeArea(
                        // MnemonicWidget owns its own scroll and docks the
                        // in-app keyboard at the bottom, so it fills the space.
                        child: IgnorePointer(
                          ignoring:
                              _scanning ||
                              state.onboardingStepStatus ==
                                  OnboardingStepStatus.loading,
                          child: Opacity(
                            opacity:
                                _scanning ||
                                    state.onboardingStepStatus ==
                                        OnboardingStepStatus.loading
                                ? 0.5
                                : 1.0,
                            child: MnemonicWidget(
                              englishOnly: true,
                              initialLength: bip39.MnemonicLength.words12,
                              allowMultipleMnemonicLength: true,
                              allowLabel: false,
                              allowPassphrase: true,
                              submitLabel: context.loc.onboardingRecover,
                              onSubmit: (mnemonic) =>
                                  unawaited(_submit(mnemonic)),
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
