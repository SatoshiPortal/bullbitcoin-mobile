import 'package:bb_mobile/features/key_server/presentation/bloc/key_server_cubit.dart';
import 'package:bb_mobile/features/key_server/ui/screens/confirm_screen.dart';
import 'package:bb_mobile/features/key_server/ui/screens/enter_screen.dart';
import 'package:bb_mobile/features/key_server/ui/screens/recover_with_backup_key_screen.dart';
import 'package:bb_mobile/features/key_server/ui/screens/recover_with_secret_screen.dart';
import 'package:bb_mobile/features/key_server/ui/widgets/error_screen.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/loading/progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart'
    show
        BlocBuilder,
        BlocListener,
        BlocProvider,
        MultiBlocListener,
        MultiBlocProvider,
        ReadContext,
        WatchContext;
import 'package:go_router/go_router.dart';

class KeyLoadingScreen extends StatelessWidget {
  const KeyLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProgressScreen(
      description: 'This will only take a few seconds',
    );
  }
}

class KeyServerFlow extends StatelessWidget {
  const KeyServerFlow({
    super.key,
    this.backupFile,
    this.currentFlow,
    this.fromOnboarding = false,
  });
  final String? backupFile;
  final String? currentFlow;
  final bool fromOnboarding;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(
          value: locator<KeyServerCubit>()
            ..updateKeyServerState(
              backupFile: backupFile,
              flow: CurrentKeyServerFlow.fromString(currentFlow ?? ''),
            ),
        ),
        BlocProvider.value(value: locator<OnboardingBloc>()),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<OnboardingBloc, OnboardingState>(
            listener: (context, walletState) {
              final keyState = context.read<KeyServerCubit>().state;
              if (keyState.status == const KeyServerOperationStatus.success() &&
                  keyState.secretStatus == SecretStatus.recovered &&
                  walletState.onboardingStepStatus ==
                      const OnboardingStepStatus.success()) {
                context.goNamed(OnboardingSubroute.recoverSuccess.name);
              }
            },
          ),
          BlocListener<BackupWalletBloc, BackupWalletState>(
            listener: (context, state) {
              if (state.status == const BackupWalletStatus.success()) {
                context.goNamed(BackupWalletSubroute.backupSuccess.name);
              }
            },
          ),
        ],
        child: BlocBuilder<KeyServerCubit, KeyServerState>(
          buildWhen: (previous, current) =>
              previous.currentFlow != current.currentFlow ||
              previous.status != current.status ||
              previous.password != current.password ||
              previous.secretStatus != current.secretStatus,
          builder: (context, state) {
            final walletState = context.watch<OnboardingBloc>().state;

            // Show loading screen
            if (state.status == const KeyServerOperationStatus.loading() ||
                (state.status == const KeyServerOperationStatus.success() &&
                    state.secretStatus == SecretStatus.recovered &&
                    walletState.onboardingStepStatus !=
                        const OnboardingStepStatus.success())) {
              if (state.status == const KeyServerOperationStatus.success() &&
                  state.secretStatus == SecretStatus.recovered &&
                  walletState.onboardingStepStatus ==
                      const OnboardingStepStatus.none()) {
                context.read<OnboardingBloc>().add(
                      StartWalletRecovery(
                        backupKey: state.backupKey,
                        backupFile: state.backupFile,
                      ),
                    );
              }
              return const KeyLoadingScreen();
            }

            // Show error screen
            if (state.status.maybeWhen(
              failure: (_) => true,
              orElse: () => false,
            )) {
              return ErrorScreen(
                message: state.status.maybeWhen(
                  failure: (message) => message,
                  orElse: () => 'An error occurred',
                ),
                title: 'Oops! Something went wrong',
                onRetry: () {
                  context.read<KeyServerCubit>()
                    ..clearError()
                    ..updateKeyServerState(
                      flow: CurrentKeyServerFlow.enter,
                    );
                },
              );
            }

            if (walletState.onboardingStepStatus.maybeWhen(
              error: (_) => true,
              orElse: () => false,
            )) {
              return ErrorScreen(
                message: state.status.maybeWhen(
                  failure: (message) => message,
                  orElse: () => 'An error occurred',
                ),
                title: 'Oops! Something went wrong',
                onRetry: () {
                  context.read<KeyServerCubit>()
                    ..clearError()
                    ..updateKeyServerState(
                      flow: CurrentKeyServerFlow.enter,
                    );
                },
              );
            }

            // Show flow screens
            return switch (state.currentFlow) {
              CurrentKeyServerFlow.enter => const EnterScreen(),
              CurrentKeyServerFlow.confirm => const ConfirmScreen(),
              CurrentKeyServerFlow.recovery => RecoverWithSecretScreen(
                  fromOnboarding: fromOnboarding,
                ),
              CurrentKeyServerFlow.delete => const EnterScreen(),
              CurrentKeyServerFlow.recoveryWithBackupKey =>
                RecoverWithBackupKeyScreen(
                  fromOnboarding: fromOnboarding,
                ),
            };
          },
        ),
      ),
    );
  }
}
