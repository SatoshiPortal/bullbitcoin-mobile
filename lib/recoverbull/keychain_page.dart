import 'dart:convert';

import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/page_template.dart';
import 'package:bb_mobile/recoverbull/bloc/backup_settings_cubit.dart';
import 'package:bb_mobile/recoverbull/bloc/backup_settings_state.dart';
import 'package:bb_mobile/recoverbull/bloc/keychain_cubit.dart';
import 'package:bb_mobile/recoverbull/bloc/keychain_state.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class KeychainBackupPage extends StatelessWidget {
  KeychainBackupPage({
    super.key,
    this.backupKey,
    required String pState,
    required this.backup,
  }) : _pState = KeyChainPageState.fromString(pState);

  final String? backupKey;
  final KeyChainPageState _pState;
  final Map<String, dynamic> backup;

  @override
  Widget build(BuildContext context) {
    // Extract backup data
    final backupId = backup['id'] as String?;
    final backupSalt = backup['salt'] as String?;

    return MultiBlocProvider(
      providers: [
        BlocProvider<KeychainCubit>(
          create: (context) => KeychainCubit()
            ..setChainState(
              _pState,
              backupId ?? '',
              backupKey,
              backupSalt ?? '',
            )
            ..keyServerStatus(),
        ),
        BlocProvider.value(value: createBackupSettingsCubit()),
      ],
      child: _Screen(
        backupKey: backupKey,
        backup: backup,
        pState: _pState,
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({this.backupKey, required this.backup, required this.pState});

  final String? backupKey;
  final Map<String, dynamic> backup;
  final KeyChainPageState pState;
  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<BackupSettingsCubit, BackupSettingsState>(
          listenWhen: (previous, current) =>
              previous.errorLoadingBackups != current.errorLoadingBackups ||
              previous.loadingBackups != current.loadingBackups ||
              previous.loadedBackups != current.loadedBackups,
          listener: (context, state) {
            // Always close loading dialog first if it's open
            if (state.loadingBackups == false) {
              Navigator.of(context).pop(); // Close loading dialog
            }

            // Handle errors
            if (state.errorLoadingBackups.isNotEmpty) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => _ErrorDialog(
                  error: state.errorLoadingBackups,
                ),
              );
              return;
            }

            if (state.loadingBackups) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const _LoadingView(),
              );
              return;
            }

            // Only show success if we have loaded backups and no errors
            if (!state.loadingBackups &&
                state.loadedBackups.isNotEmpty &&
                state.errorLoadingBackups.isEmpty) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => _SuccessDialog(
                  pageState: pState,
                ),
              );
            }
          },
        ),
        BlocListener<KeychainCubit, KeychainState>(
          listenWhen: (previous, current) =>
              previous.isSecretConfirmed != current.isSecretConfirmed ||
              previous.keySecretState != current.keySecretState ||
              previous.error != current.error,
          listener: (context, state) {
            if (state.pageState == KeyChainPageState.delete &&
                state.keySecretState == KeySecretState.deleted &&
                !state.loading &&
                !state.hasError) {
              context.read<KeychainCubit>().clearSensitive();

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => _SuccessDialog(
                  pageState: pState,
                ),
              );
            }

            if (state.isSecretConfirmed &&
                !state.loading &&
                !state.hasError &&
                state.keySecretState == KeySecretState.none) {
              context.read<KeychainCubit>().secureKey();
            }

            if (state.keySecretState == KeySecretState.saved &&
                !state.loading &&
                !state.hasError) {
              context.read<KeychainCubit>().clearSensitive();
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => _SuccessDialog(
                  pageState: pState,
                ),
              );
            }
            if (state.keySecretState == KeySecretState.recovered &&
                !state.loading &&
                !state.hasError &&
                backup.isNotEmpty &&
                state.backupKey.isNotEmpty) {
              if (state.pageState == KeyChainPageState.download) {
                context.push(
                  '/wallet-settings/backup-settings/key/options',
                  extra: (state.backupKey, backup),
                );
              } else {
                context.read<BackupSettingsCubit>().recoverBackup(
                      jsonEncode(backup),
                      state.backupKey,
                    );
              }
            }

            if (state.hasError && state.keyServerUp) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => _ErrorDialog(
                  error: state.error,
                  isRecovery: state.pageState == KeyChainPageState.recovery,
                ),
              );
            }
          },
        ),
        BlocListener<KeychainCubit, KeychainState>(
          listenWhen: (previous, current) =>
              previous.keyServerUp != current.keyServerUp,
          listener: (context, state) {
            if (!state.keyServerUp &&
                state.inputType != KeyChainInputType.backupKey) {
              context.read<KeychainCubit>().updatePageState(
                    KeyChainInputType.backupKey,
                    state.pageState,
                  );
            }
          },
        ),
      ],
      child: BlocBuilder<KeychainCubit, KeychainState>(
        builder: (context, state) {
          if (state.loading) return const _LoadingView();

          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              elevation: 0,
              flexibleSpace: BBAppBar(
                text:
                    state.isRecovering ? 'Recover Keychain' : 'Keychain Backup',
                onBack: () {
                  context.read<KeychainCubit>().clearSensitive();
                  context.pop();
                },
              ),
            ),
            body: AnimatedSwitcher(
              duration: 300.ms,
              child: _buildPageContent(state),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageContent(KeychainState state) {
    switch (state.pageState) {
      case KeyChainPageState.recovery:
        return _RecoveryPage(
          key: const ValueKey('recovery'),
          inputType: state.inputType,
        );
      case KeyChainPageState.enter:
        return _EnterPage(
          key: const ValueKey('enter'),
          inputType: state.inputType,
        );
      case KeyChainPageState.confirm:
        return _ConfirmPage(
          key: const ValueKey('confirm'),
          inputType: state.inputType,
        );
      case KeyChainPageState.delete:
        return _DeletePage(
          key: const ValueKey('delete'),
          inputType: state.inputType,
        );
      case KeyChainPageState.download:
        return _RecoveryPage(
          key: const ValueKey('view'),
          inputType: state.inputType,
        );
    }
  }
}

/// Page Type Widgets
class _EnterPage extends StatelessWidget {
  const _EnterPage({super.key, required this.inputType});
  final KeyChainInputType inputType;

  @override
  Widget build(BuildContext context) {
    return StackedPage(
      bottomChildHeight: MediaQuery.of(context).size.height * 0.11,
      bottomChild: _SetButton(inputType: inputType),
      child: Padding(
        key: ValueKey('enter$inputType'),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(50),
            const _TitleText(),
            const Gap(8),
            const _SubtitleText(),
            const Gap(50),
            if (inputType == KeyChainInputType.pin) ...[
              _PinField(),
              const KeyPad(),
            ] else
              _PasswordField(),
            const Gap(30),
          ],
        ),
      ),
    );
  }
}

class _ConfirmPage extends StatelessWidget {
  const _ConfirmPage({super.key, required this.inputType});
  final KeyChainInputType inputType;

  @override
  Widget build(BuildContext context) {
    return StackedPage(
      bottomChild: _ConfirmButton(inputType: inputType),
      bottomChildHeight: MediaQuery.of(context).size.height * 0.11,
      child: SingleChildScrollView(
        key: ValueKey('confirm$inputType'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Gap(20),
              const _ConfirmTitleText(),
              const Gap(8),
              const _ConfirmSubtitleText(),
              const Gap(48),
              if (inputType == KeyChainInputType.pin) ...[
                _PinField(),
                const KeyPad(),
              ] else
                _PasswordField(),
              const Gap(24),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecoveryPage extends StatelessWidget {
  const _RecoveryPage({super.key, required this.inputType});
  final KeyChainInputType inputType;

  @override
  Widget build(BuildContext context) {
    return StackedPage(
      bottomChildHeight: MediaQuery.of(context).size.height * 0.16,
      bottomChild: _RecoverButton(inputType: inputType),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(50),
            BBText.titleLarge(
              'Enter Recovery ${_getInputTypeText(inputType)}',
              textAlign: TextAlign.center,
              isBold: true,
            ),
            const Gap(8),
            BBText.bodySmall(
              'Enter the ${_getInputTypeText(inputType).toLowerCase()} you used to backup your keychain',
              textAlign: TextAlign.center,
            ),
            const Gap(50),
            if (inputType == KeyChainInputType.pin) ...[
              _PinField(),
              const KeyPad(),
            ] else
              _PasswordField(),
            const Gap(30),
          ],
        ),
      ),
    );
  }

  String _getInputTypeText(KeyChainInputType type) {
    switch (type) {
      case KeyChainInputType.pin:
        return 'PIN';
      case KeyChainInputType.password:
        return 'Password';
      case KeyChainInputType.backupKey:
        return 'Key';
    }
  }
}

class _DeletePage extends StatelessWidget {
  const _DeletePage({super.key, required this.inputType});
  final KeyChainInputType inputType;

  @override
  Widget build(BuildContext context) {
    return StackedPage(
      bottomChildHeight: MediaQuery.of(context).size.height * 0.11,
      bottomChild: _DeleteButton(inputType: inputType),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(50),
            const BBText.titleLarge(
              'Delete Backup Key',
              textAlign: TextAlign.center,
              isBold: true,
            ),
            const Gap(8),
            BBText.bodySmall(
              'Enter your ${inputType == KeyChainInputType.pin ? 'PIN' : 'password'} to delete this backup key',
              textAlign: TextAlign.center,
            ),
            const Gap(50),
            if (inputType == KeyChainInputType.pin) ...[
              _PinField(),
              const KeyPad(),
            ] else
              _PasswordField(),
            const Gap(30),
          ],
        ),
      ),
    );
  }
}

/// Input Widgets
class _PinField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.select((KeychainCubit x) => x.state);
    final error = state.getValidationError();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 40),
              Expanded(
                child: Center(
                  child: BBText.titleLarge(state.displayPin(), isBold: true),
                ),
              ),
              SizedBox(
                width: 40,
                child: IconButton(
                  iconSize: 32,
                  color: state.secret.isEmpty
                      ? context.colour.surface
                      : context.colour.onPrimaryContainer,
                  splashColor: Colors.transparent,
                  onPressed: () {
                    SystemSound.play(SystemSoundType.click);
                    HapticFeedback.mediumImpact();
                    context.read<KeychainCubit>().backspacePressed();
                  },
                  icon: const FaIcon(FontAwesomeIcons.deleteLeft),
                ),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(child: BBText.errorSmall(error)),
          ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KeychainCubit, KeychainState>(
      buildWhen: (previous, current) =>
          previous.secret != current.secret ||
          previous.obscure != current.obscure ||
          previous.inputType != current.inputType ||
          previous.backupKey != current.backupKey ||
          previous.error != current.error,
      builder: (context, state) {
        final isBackupKeyMode = state.inputType == KeyChainInputType.backupKey;
        final value = isBackupKeyMode ? state.backupKey : state.secret;
        final error = state.getValidationError();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BBTextInput.bigWithIcon(
              value: value,
              onChanged: (value) => isBackupKeyMode
                  ? context.read<KeychainCubit>().updateBackupKey(value)
                  : context.read<KeychainCubit>().updateInput(value),
              obscure: !isBackupKeyMode && state.obscure,
              hint: isBackupKeyMode
                  ? 'Enter your backup key'
                  : 'Enter your password',
              rightIcon: isBackupKeyMode
                  ? null
                  : Icon(
                      state.obscure ? Icons.visibility_off : Icons.visibility,
                      color: context.colour.onPrimaryContainer,
                    ),
              onRightTap: isBackupKeyMode
                  ? null
                  : () => context.read<KeychainCubit>().clickObscure(),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 8),
                child: BBText.errorSmall(error),
              ),
          ],
        );
      },
    );
  }
}

class KeyPad extends StatelessWidget {
  const KeyPad({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
        children: [
          for (var i = 0; i < 9; i = i + 1) NumberButton(text: i.toString()),
        ],
      ),
    );
  }
}

class NumberButton extends StatefulWidget {
  const NumberButton({super.key, required this.text});

  final String text;

  @override
  State<NumberButton> createState() => _NumberButtonState();
}

class _NumberButtonState extends State<NumberButton> {
  bool isRed = false;

  @override
  Widget build(BuildContext context) {
    OutlinedButton.styleFrom(
      shape: const CircleBorder(),
      backgroundColor: context.colour.onPrimaryContainer,
      foregroundColor: context.colour.primary,
    );

    OutlinedButton.styleFrom(
      shape: const CircleBorder(),
      backgroundColor: context.colour.primary,
      foregroundColor: context.colour.primaryContainer,
    );

    return Center(
      child: SizedBox(
        height: 80,
        width: 80,
        child: GestureDetector(
          onTapUp: (e) => setState(() => isRed = false),
          onTapDown: (e) => setState(() => isRed = true),
          onTapCancel: () => setState(() => isRed = false),
          child: OutlinedButton(
            style:
                OutlinedButton.styleFrom(splashFactory: NoSplash.splashFactory),
            onPressed: () {
              SystemSound.play(SystemSoundType.click);
              HapticFeedback.mediumImpact();
              context.read<KeychainCubit>().keyPressed(widget.text);
            },
            child: BBText.titleLarge(widget.text, isBold: true),
          ).animate().blur(
                begin: const Offset(1, 1),
                end: isRed ? const Offset(2, 2) : Offset.zero,
              ),
        ),
      ),
    );
  }
}

/// Action Buttons
class _SetButton extends StatelessWidget {
  final KeyChainInputType inputType;
  const _SetButton({required this.inputType});
  @override
  Widget build(BuildContext context) {
    final state = context.select((KeychainCubit x) => x.state);
    final canStoreKey = state.canStoreKey;
    final keyServerUp = state.keyServerUp;

    // Don't show the button if keyserver is down
    if (!keyServerUp) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              final cubit = context.read<KeychainCubit>();
              if (inputType == KeyChainInputType.pin) {
                cubit.updatePageState(
                  KeyChainInputType.password,
                  KeyChainPageState.enter,
                );
              } else {
                cubit.updatePageState(
                  KeyChainInputType.pin,
                  KeyChainPageState.enter,
                );
              }
            },
            child: BBText.bodySmall(
              inputType == KeyChainInputType.pin
                  ? 'Use a password instead of a pin'
                  : 'Use a PIN instead of a password',
              isBold: true,
            ),
          ),
          const Gap(5),
          BBButton.withColour(
            fillWidth: true,
            label:
                'Set ${inputType == KeyChainInputType.pin ? 'PIN' : 'password'}',
            disabled: !canStoreKey,
            onPressed: () {
              context.read<KeychainCubit>().keyServerStatus();
              if (canStoreKey) context.read<KeychainCubit>().confirmPressed();
            },
          ),
        ],
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({required this.inputType});
  final KeyChainInputType inputType;
  @override
  Widget build(BuildContext context) {
    final canStoreKey =
        context.select((KeychainCubit x) => x.state.canStoreKey);
    final err = context.select((KeychainCubit x) => x.state.error);

    if (err.isNotEmpty && inputType == KeyChainInputType.password) {
      return Center(child: BBText.errorSmall(err));
    }
    return BBButton.withColour(
      fillWidth: true,
      onPressed: () {
        context.read<KeychainCubit>().keyServerStatus();
        if (canStoreKey) context.read<KeychainCubit>().confirmPressed();
      },
      leftIcon: Icons.arrow_forward,
      label:
          'Confirm ${inputType == KeyChainInputType.pin ? 'PIN' : 'password'}',
      disabled: !canStoreKey,
    );
  }
}

class _RecoverButton extends StatelessWidget {
  const _RecoverButton({required this.inputType});
  final KeyChainInputType inputType;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KeychainCubit, KeychainState>(
      buildWhen: (previous, current) =>
          previous.canRecoverKey != current.canRecoverKey ||
          previous.loading != current.loading ||
          previous.pageState != current.pageState ||
          previous.keyServerUp != current.keyServerUp,
      builder: (context, state) {
        final canRecover = inputType == KeyChainInputType.backupKey
            ? state.canRecoverWithBckupKey
            : state.canRecoverKey;

        // Check if we're in the download flow by checking original state
        final isDownloadFlow = state.pageState == KeyChainPageState.download ||
            state.originalPageState == KeyChainPageState.download;

        // Show only backup key option if server is down
        if (!state.keyServerUp && inputType != KeyChainInputType.backupKey) {
          return Column(
            children: [
              const BBText.bodySmall(
                'Server is currently unavailable.\nPlease use your backup key to recover.',
                textAlign: TextAlign.center,
                isRed: true,
              ),
              const Gap(16),
              BBButton.withColour(
                fillWidth: true,
                label: 'Switch to Backup Key',
                onPressed: () => _switchToBackupKey(context),
              ),
            ],
          );
        }

        return Column(
          children: [
            const Gap(10),
            // Always show PIN/password switch
            InkWell(
              onTap: () => _switchInputType(context),
              child: BBText.bodySmall(_getSwitchButtonText(), isBold: true),
            ),
            if (!isDownloadFlow &&
                inputType != KeyChainInputType.backupKey) ...[
              const Gap(10),
              InkWell(
                onTap: () => _switchToBackupKey(context),
                child: const BBText.bodySmall(
                  'Recover with backup key',
                  isBold: true,
                ),
              ),
            ],
            const Gap(8),
            BBButton.withColour(
              fillWidth: true,
              label: 'Recover with ${_getInputTypeText()}',
              leftIcon: Icons.arrow_forward_rounded,
              disabled: !canRecover,
              loading: state.loading,
              onPressed: () => context.read<KeychainCubit>().clickRecover(),
            ),
          ],
        );
      },
    );
  }

  void _switchInputType(BuildContext context) {
    final cubit = context.read<KeychainCubit>();
    final newType = inputType == KeyChainInputType.pin
        ? KeyChainInputType.password
        : KeyChainInputType.pin;
    cubit.updatePageState(newType, KeyChainPageState.recovery);
  }

  void _switchToBackupKey(BuildContext context) {
    context.read<KeychainCubit>().updatePageState(
          KeyChainInputType.backupKey,
          KeyChainPageState.recovery,
        );
  }

  String _getSwitchButtonText() {
    switch (inputType) {
      case KeyChainInputType.pin:
        return 'Use a password instead of a PIN';
      case KeyChainInputType.password:
        return 'Use a PIN instead of a password';
      case KeyChainInputType.backupKey:
        return 'Use a PIN instead of a backup key';
    }
  }

  String _getInputTypeText() {
    switch (inputType) {
      case KeyChainInputType.pin:
        return 'PIN';
      case KeyChainInputType.password:
        return 'password';
      case KeyChainInputType.backupKey:
        return 'backup key';
    }
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.inputType});
  final KeyChainInputType inputType;

  @override
  Widget build(BuildContext context) {
    final canDeleteKey =
        context.select((KeychainCubit x) => x.state.canDeleteKey);
    return FilledButton(
      onPressed: () => canDeleteKey ? _showDeleteConfirmation(context) : null,
      style: FilledButton.styleFrom(
        backgroundColor: context.colour.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Delete Backup Key',
            style: context.font.bodyMedium!.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.delete_forever, color: Colors.white, size: 20),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const BBText.title('Delete Backup Key?', isBold: true),
        content: const BBText.bodySmall(
          'This action cannot be undone. Are you sure you want to delete this backup key?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: context.font.bodyMedium,
            ),
          ),
          FilledButton(
            onPressed: () {
              // First close the dialog
              Navigator.of(dialogContext).pop();
              // Then trigger the delete action using the original context
              context.read<KeychainCubit>().deleteBackupKey();
            },
            style: FilledButton.styleFrom(
              backgroundColor: context.colour.shadow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Delete',
                style: context.font.bodyMedium!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                )),
          ),
        ],
      ),
    );
  }
}

/// Dialog Widgets
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: context.colour.primary),
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({required this.pageState});

  final KeyChainPageState pageState;

  @override
  Widget build(BuildContext context) {
    String title;
    String message;
    String route;
    dynamic extra;

    if (pageState == KeyChainPageState.recovery) {
      title = 'Recovery Successful';
      message = 'Your wallet has been recovered successfully';
      route = '/home';
    } else if (pageState == KeyChainPageState.enter) {
      title = 'Backup Successful';
      message =
          'Your wallet has been backed up successfully \n Please test your backup';
      route = '/wallet-settings/backup-settings/recover-options/encrypted';
      extra = false;
    } else if (pageState == KeyChainPageState.delete) {
      title = 'Backup Key Deleted';
      message = 'Your backup key has been permanently deleted';
      route = '/home';
    } else {
      title = 'Backup Downloaded';
      message = 'Your backup has been downloaded successfully';
      route = '/home';
    }

    return Dialog(
      backgroundColor: context.colour.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: context.colour.primary,
              size: 48,
            ),
            const Gap(16),
            BBText.title(title, textAlign: TextAlign.center, isBold: true),
            const Gap(8),
            BBText.bodySmall(message, textAlign: TextAlign.center),
            const Gap(24),
            BBButton.withColour(
              label: 'Continue',
              onPressed: () {
                Navigator.of(context).pop();
                if (extra != null) {
                  context.push(route, extra: extra);
                } else {
                  context.go(route);
                }
              },
            )
          ],
        ),
      ),
    );
  }
}

class _ErrorDialog extends StatelessWidget {
  const _ErrorDialog({required this.error, this.isRecovery = false});
  final String error;
  final bool isRecovery;
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colour.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: context.colour.primary,
              size: 48,
            ),
            const Gap(16),
            BBText.title(isRecovery ? 'Recovery failed' : 'Backup failed',
                textAlign: TextAlign.center, isBold: true),
            const Gap(8),
            BBText.bodySmall(error, textAlign: TextAlign.center),
            const Gap(24),
            BBButton.withColour(
              label: 'Continue',
              onPressed: () {
                Navigator.of(context).pop();
              },
            )
          ],
        ),
      ),
    );
  }
}

/// Text Widgets
class _TitleText extends StatelessWidget {
  const _TitleText();

  @override
  Widget build(BuildContext context) {
    final (inputState, type) = context
        .select((KeychainCubit x) => (x.state.pageState, x.state.inputType));
    final text = inputState == KeyChainPageState.enter
        ? 'Choose a backup ${type == KeyChainInputType.pin ? 'PIN' : 'password'}'
        : 'Confirm backup ${type == KeyChainInputType.pin ? 'PIN' : 'password'}';
    return BBText.titleLarge(textAlign: TextAlign.center, text, isBold: true);
  }
}

class _ConfirmTitleText extends StatelessWidget {
  const _ConfirmTitleText();

  @override
  Widget build(BuildContext context) {
    final (pageState, inputType) = context
        .select((KeychainCubit x) => (x.state.pageState, x.state.inputType));
    final text =
        'Confirm backup ${inputType == KeyChainInputType.pin ? 'PIN' : 'password'}';

    return BBText.titleLarge(textAlign: TextAlign.center, text, isBold: true);
  }
}

class _ConfirmSubtitleText extends StatelessWidget {
  const _ConfirmSubtitleText();

  @override
  Widget build(BuildContext context) {
    final inputType = context.select((KeychainCubit x) => x.state.inputType);
    return BBText.bodySmall(
      textAlign: TextAlign.center,
      'Enter the ${inputType == KeyChainInputType.pin ? 'PIN' : 'password'} again to confirm',
    );
  }
}

class _SubtitleText extends StatelessWidget {
  const _SubtitleText();

  @override
  Widget build(BuildContext context) {
    final inputType = context.select((KeychainCubit x) => x.state.inputType);
    final text =
        'You must memorize this ${inputType == KeyChainInputType.pin ? 'PIN' : 'password'} to recover access to your wallet. It must be at least ${KeychainCubit.pinMin} digits.';
    return BBText.bodySmall(textAlign: TextAlign.center, text);
  }
}
