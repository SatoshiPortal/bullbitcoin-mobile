import 'package:bb_mobile/core/recoverbull/domain/entity/key_server.dart'
    show CurrentKeyServerFlow, SecretStatus;
import 'package:bb_mobile/core/widgets/loading/status_screen.dart';
import 'package:bb_mobile/features/backup_wallet/presentation/bloc/backup_wallet_bloc.dart';
import 'package:bb_mobile/features/backup_wallet/ui/backup_wallet_router.dart';
import 'package:bb_mobile/features/key_server/presentation/bloc/key_server_cubit.dart';
import 'package:bb_mobile/features/key_server/ui/screens/confirm_screen.dart';
import 'package:bb_mobile/features/key_server/ui/screens/enter_screen.dart';
import 'package:bb_mobile/features/key_server/ui/screens/recover_with_backup_key_screen.dart';
import 'package:bb_mobile/features/key_server/ui/screens/recover_with_secret_screen.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/test_wallet_backup_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'
    show
        BlocListener,
        BlocProvider,
        MultiBlocListener,
        MultiBlocProvider,
        ReadContext,
        SelectContext;
import 'package:go_router/go_router.dart';

class KeyServerFlow extends StatefulWidget {
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
  State<KeyServerFlow> createState() => _KeyServerFlowState();
}

class _KeyServerFlowState extends State<KeyServerFlow> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(
            value:
                locator<KeyServerCubit>()..updateKeyServerState(
                  backupFile: widget.backupFile,
                  flow: CurrentKeyServerFlow.fromString(
                    widget.currentFlow ?? '',
                  ),
                ),
          ),
          BlocProvider.value(value: locator<OnboardingBloc>()),
          BlocProvider.value(value: locator<BackupWalletBloc>()),
          BlocProvider.value(value: locator<TestWalletBackupBloc>()),
        ],
        child: MultiBlocListener(
          listeners: [
            BlocListener<KeyServerCubit, KeyServerState>(
              listener: _handleKeyServerStateChange,
            ),
            BlocListener<TestWalletBackupBloc, TestWalletBackupState>(
              listener: _handleTestBackupStateChange,
            ),
            BlocListener<OnboardingBloc, OnboardingState>(
              listener: _handleOnboardingStateChange,
            ),
          ],
          child: Builder(
            builder: (context) {
              final keyStatus = context.select(
                (KeyServerCubit c) => c.state.status,
              );
              final keyFlow = context.select(
                (KeyServerCubit c) => c.state.currentFlow,
              );
              final onboardingStatus = context.select(
                (OnboardingBloc b) => b.state.onboardingStepStatus,
              );
              final onboardingError = context.select(
                (OnboardingBloc b) => b.state.statusError,
              );
              final testStatus = context.select(
                (TestWalletBackupBloc b) => b.state.status,
              );

              if (_isLoading(keyStatus, onboardingStatus, testStatus) ||
                  _hasError(keyStatus, onboardingError, testStatus)) {
                return StatusScreen(
                  isLoading: _isLoading(
                    keyStatus,
                    onboardingStatus,
                    testStatus,
                  ),
                  hasError: _hasError(keyStatus, onboardingError, testStatus),
                  title: _getTitle(
                    _hasError(keyStatus, onboardingError, testStatus),
                  ),
                  description: _getMessage(
                    _isLoading(keyStatus, onboardingStatus, testStatus),
                  ),
                  errorMessage: _getErrorMessage(
                    keyStatus,
                    onboardingError,
                    testStatus,
                  ),
                  onTap:
                      _hasError(keyStatus, onboardingError, testStatus)
                          ? () => _handleError(context)
                          : null,
                );
              }

              switch (keyFlow) {
                case CurrentKeyServerFlow.enter:
                  return const EnterScreen();
                case CurrentKeyServerFlow.confirm:
                  return const ConfirmScreen();
                case CurrentKeyServerFlow.recovery:
                  return onboardingStatus == OnboardingStepStatus.success ||
                          testStatus == TestWalletBackupStatus.success
                      ? const Scaffold()
                      : RecoverWithSecretScreen(
                        fromOnboarding: widget.fromOnboarding,
                      );
                case CurrentKeyServerFlow.delete:
                  return const EnterScreen();
                case CurrentKeyServerFlow.recoveryWithBackupKey:
                  return RecoverWithBackupKeyScreen(
                    fromOnboarding: widget.fromOnboarding,
                  );
              }
            },
          ),
        ),
      ),
    );
  }

  bool _isLoading(
    KeyServerOperationStatus keyStatus,
    OnboardingStepStatus onboardingStatus,
    TestWalletBackupStatus testStatus,
  ) =>
      keyStatus == const KeyServerOperationStatus.loading() ||
      onboardingStatus == OnboardingStepStatus.loading ||
      testStatus == TestWalletBackupStatus.loading;

  bool _hasError(
    KeyServerOperationStatus keyStatus,
    String onboardingError,
    TestWalletBackupStatus testStatus,
  ) =>
      switch (keyStatus) {
        KeyServerFailure _ => true,
        _ => false,
      } ||
      onboardingError.isNotEmpty ||
      testStatus == TestWalletBackupStatus.error;

  String? _getTitle(bool hasError) {
    if (hasError) return 'Oops! Something went wrong';
    return null;
  }

  String? _getMessage(bool isLoading) {
    if (isLoading) {
      return 'Connecting to Key Server over Tor.\nThis can take upto a minute.';
    }
    return null;
  }

  String? _getErrorMessage(
    KeyServerOperationStatus keyStatus,
    String onboardingError,
    TestWalletBackupStatus testStatus,
  ) {
    if (!_hasError(keyStatus, onboardingError, testStatus)) return null;

    return switch (keyStatus) {
      KeyServerFailure(:final message) => message,
      _ =>
        onboardingError.isNotEmpty
            ? onboardingError
            : testStatus == TestWalletBackupStatus.error
            ? 'An error occurred'
            : null,
    };
  }

  void _handleError(BuildContext context) {
    if (CurrentKeyServerFlow.fromString(widget.currentFlow ?? '') ==
        CurrentKeyServerFlow.recovery) {
      context.read<KeyServerCubit>().updateKeyServerState(
        backupFile: widget.backupFile,
        status: const KeyServerOperationStatus.initial(),
        flow: CurrentKeyServerFlow.fromString(widget.currentFlow ?? ''),
      );
    } else {
      context.read<KeyServerCubit>()
        ..clearError()
        ..updateKeyServerState(flow: CurrentKeyServerFlow.enter);
    }
    if (mounted && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleOnboardingStateChange(
    BuildContext context,
    OnboardingState state,
  ) {
    if (state.onboardingStepStatus == OnboardingStepStatus.success) {
      context.read<WalletBloc>().add(const WalletStarted());
      context.goNamed(WalletRoute.walletHome.name);
    }
  }

  void _handleRecoverySuccess(BuildContext context, KeyServerState state) {
    final onBoardingState = context.read<OnboardingBloc>().state;
    final testWalletBackupState = context.read<TestWalletBackupBloc>().state;

    if (widget.fromOnboarding &&
        onBoardingState.onboardingStepStatus == OnboardingStepStatus.none) {
      context.read<OnboardingBloc>().add(
        StartWalletRecovery(
          backupKey: state.backupKey,
          backupFile: state.backupFile,
        ),
      );
    } else if (!(testWalletBackupState.status ==
            TestWalletBackupStatus.success) &&
        !widget.fromOnboarding) {
      context.read<TestWalletBackupBloc>().add(
        StartVaultBackupTesting(
          backupKey: state.backupKey,
          backupFile: state.backupFile,
        ),
      );
    }
  }

  void _handleKeyServerStateChange(BuildContext context, KeyServerState state) {
    if (state.status != const KeyServerOperationStatus.success()) return;

    if (state.secretStatus == SecretStatus.stored) {
      context.goNamed(BackupWalletSubroute.backupSuccess.name);
    } else if (state.secretStatus == SecretStatus.recovered) {
      _handleRecoverySuccess(context, state);
    }
  }

  void _handleTestBackupStateChange(
    BuildContext context,
    TestWalletBackupState state,
  ) {
    if (state.status == TestWalletBackupStatus.success) {
      context.goNamed(TestWalletBackupSubroute.backupTestSuccess.name);
    }
  }
}
