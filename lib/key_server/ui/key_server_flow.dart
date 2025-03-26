import 'package:bb_mobile/_ui/components/loading/progress_screen.dart';
import 'package:bb_mobile/_ui/components/template/screen_template.dart'
    show StackedPage;
import 'package:bb_mobile/key_server/presentation/bloc/key_server_cubit.dart';
import 'package:bb_mobile/key_server/ui/screens/confirm_screen.dart';
import 'package:bb_mobile/key_server/ui/screens/enter_screen.dart';
import 'package:bb_mobile/key_server/ui/screens/recover_with_backup_key_screen.dart';
import 'package:bb_mobile/key_server/ui/screens/recover_with_secret_screen.dart';
import 'package:bb_mobile/key_server/ui/widgets/error_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/recover_wallet/presentation/bloc/recover_wallet_bloc.dart';
import 'package:bb_mobile/recover_wallet/ui/recover_wallet_router.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart'
    show BlocBuilder, BlocProvider, MultiBlocProvider, ReadContext;
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

class BackupSuccessScreen extends StatelessWidget {
  const BackupSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProgressScreen(
      description:
          'Now let’s test your backup to make sure everything was done properly.',
      title: 'Backup completed!',
      isLoading: false,
      buttonText: 'Test Backup',
      onTap: () => context.pushNamed(
        RecoverWalletSubroute.chooseRecoverProvider.name,
        extra: false,
      ),
    );
  }
}

class RecoverSuccessScreen extends StatelessWidget {
  final String backupKey;
  final String backupFile;
  final bool fromOnboarding;
  const RecoverSuccessScreen({
    super.key,
    required this.backupKey,
    required this.backupFile,
    required this.fromOnboarding,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: locator<RecoverWalletBloc>()
        ..add(
          DecryptRecoveryFile(
            backupKey: backupKey,
            backupFile: backupFile,
          ),
        ),
      child: ProgressScreen(
        title: fromOnboarding
            ? 'Wallet recovered successfully!'
            : 'Test completed successfully!',
        description: fromOnboarding
            ? ''
            : 'You are able to recover access to a lost Bitcoin wallet',
        isLoading: false,
        buttonText: 'Done',
        onTap: () => context.goNamed(
          AppRoute.home.name,
          extra: false,
        ),
      ),
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
        BlocProvider.value(value: locator<RecoverWalletBloc>()),
      ],
      child: Builder(
        builder: (context) {
          return BlocBuilder<RecoverWalletBloc, RecoverWalletState>(
            builder: (context, walletState) {
              return BlocBuilder<KeyServerCubit, KeyServerState>(
                buildWhen: (previous, current) =>
                    previous.currentFlow != current.currentFlow ||
                    previous.status != current.status ||
                    previous.password != current.password ||
                    previous.secretStatus != current.secretStatus,
                builder: (context, state) {
                  final bool isLoading = state.status ==
                          const KeyServerOperationStatus.loading() ||
                      walletState.recoverWalletStatus ==
                          const RecoverWalletStatus.loading();

                  if (isLoading) {
                    return const KeyLoadingScreen();
                  }

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
                        context.read<KeyServerCubit>().clearError();
                        context.read<KeyServerCubit>().updateKeyServerState(
                              flow: CurrentKeyServerFlow.enter,
                            );
                      },
                    );
                  }

                  if (state.status ==
                          const KeyServerOperationStatus.success() &&
                      state.secretStatus == SecretStatus.stored) {
                    return const BackupSuccessScreen();
                  }

                  if (state.status ==
                          const KeyServerOperationStatus.success() &&
                      state.secretStatus == SecretStatus.recovered) {
                    return RecoverSuccessScreen(
                      backupKey: state.backupKey,
                      fromOnboarding: fromOnboarding,
                      backupFile: state.backupFile,
                    );
                  }

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
              );
            },
          );
        },
      ),
    );
  }
}

class PageLayout extends StatelessWidget {
  const PageLayout({
    required this.bottomChild,
    required this.children,
    this.bottomHeight,
  });

  final Widget bottomChild;
  final List<Widget> children;
  final double? bottomHeight;

  @override
  Widget build(BuildContext context) {
    return StackedPage(
      bottomChildHeight:
          bottomHeight ?? MediaQuery.of(context).size.height * 0.11,
      bottomChild: bottomChild,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
