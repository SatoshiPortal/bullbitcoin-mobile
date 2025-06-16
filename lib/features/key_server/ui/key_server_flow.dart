import 'package:bb_mobile/core/recoverbull/domain/entity/key_server.dart'
    show CurrentKeyServerFlow, SecretStatus;
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
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/loading/status_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart'
    show
        BlocListener,
        BlocProvider,
        MultiBlocListener,
        MultiBlocProvider,
        ReadContext,
        WatchContext;
import 'package:go_router/go_router.dart';

class KeyServerFlow extends StatefulWidget {
  const KeyServerFlow({
    super.key,
    this.backupFile,
    this.currentFlow,
    this.onboardingBloc,
  });
  final String? backupFile;
  final String? currentFlow;
  final OnboardingBloc? onboardingBloc;

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
          if (widget.onboardingBloc != null)
            BlocProvider.value(value: widget.onboardingBloc!),
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
          ],
          child: Builder(
            builder: (context) {
              final keyState = context.watch<KeyServerCubit>().state;
              final onBoardingState = context.watch<OnboardingBloc>().state;
              final testState = context.watch<TestWalletBackupBloc>().state;

              if (_isLoading(keyState, onBoardingState, testState) ||
                  _hasError(keyState, onBoardingState, testState)) {
                return StatusScreen(
                  isLoading: _isLoading(keyState, onBoardingState, testState),
                  hasError: _hasError(keyState, onBoardingState, testState),
                  title: _getTitle(keyState, onBoardingState, testState),
                  description: _getMessage(
                    keyState,
                    onBoardingState,
                    testState,
                  ),
                  errorMessage: _getErrorMessage(
                    keyState,
                    onBoardingState,
                    testState,
                  ),
                  onTap:
                      _hasError(keyState, onBoardingState, testState)
                          ? () => _handleError(context)
                          : null,
                );
              }

              switch (keyState.currentFlow) {
                case CurrentKeyServerFlow.enter:
                  return const EnterScreen();
                case CurrentKeyServerFlow.confirm:
                  return const ConfirmScreen();
                case CurrentKeyServerFlow.recovery:
                  return RecoverWithSecretScreen(
                    fromOnboarding: widget.onboardingBloc != null,
                  );
                case CurrentKeyServerFlow.delete:
                  return const EnterScreen();
                case CurrentKeyServerFlow.recoveryWithBackupKey:
                  return RecoverWithBackupKeyScreen(
                    fromOnboarding: widget.onboardingBloc != null,
                  );
              }
            },
          ),
        ),
      ),
    );
  }

  bool _isLoading(
    KeyServerState k,
    OnboardingState o,
    TestWalletBackupState t,
  ) =>
      k.status == const KeyServerOperationStatus.loading() ||
      o.onboardingStepStatus == OnboardingStepStatus.loading ||
      t.status == TestWalletBackupStatus.loading;

  bool _hasError(
    KeyServerState k,
    OnboardingState o,
    TestWalletBackupState t,
  ) =>
      switch (k.status) {
        KeyServerFailure _ => true,
        _ => false,
      } ||
      o.statusError.isNotEmpty ||
      t.status == TestWalletBackupStatus.error;

  String? _getTitle(
    KeyServerState k,
    OnboardingState o,
    TestWalletBackupState t,
  ) {
    if (_hasError(k, o, t)) return 'Oops! Something went wrong';
    return null;
  }

  String? _getMessage(
    KeyServerState k,
    OnboardingState o,
    TestWalletBackupState t,
  ) {
    if (_isLoading(k, o, t)) {
      return 'Connecting to Key Server over Tor.\nThis can take upto a minute.';
    }
    return null;
  }

  String? _getErrorMessage(
    KeyServerState k,
    OnboardingState o,
    TestWalletBackupState t,
  ) {
    if (!_hasError(k, o, t)) return null;

    return switch (k.status) {
      KeyServerFailure(:final message) => message,
      _ =>
        o.statusError.isNotEmpty
            ? o.statusError
            : t.statusError.isNotEmpty
            ? t.statusError
            : 'An error occurred',
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

  void _handleRecoverySuccess(BuildContext context, KeyServerState state) {
    final onBoardingState = context.read<OnboardingBloc>().state;
    final testWalletBackupState = context.read<TestWalletBackupBloc>().state;

    if (widget.onboardingBloc != null &&
        onBoardingState.onboardingStepStatus == OnboardingStepStatus.none) {
      context.read<OnboardingBloc>().add(
        StartWalletRecovery(
          backupKey: state.backupKey,
          backupFile: state.backupFile,
        ),
      );
    } else if (!(testWalletBackupState.status ==
            TestWalletBackupStatus.success) &&
        widget.onboardingBloc == null) {
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
