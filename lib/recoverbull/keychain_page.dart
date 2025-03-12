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
import 'package:recoverbull/recoverbull.dart';

/// Common constants
const _kGapSmall = 8.0;
const _kGapMedium = 16.0;
const _kGapLarge = 24.0;
const _kGapXLarge = 50.0;
const _kHorizontalPadding = 32.0;

class KeychainBackupPage extends StatefulWidget {
  KeychainBackupPage({
    super.key,
    this.backupKey,
    required String pState,
    required this.backup,
  }) : _pState = KeyChainFlow.fromString(pState);

  final String? backupKey;
  final KeyChainFlow _pState;
  final BullBackup backup;

  @override
  State<KeychainBackupPage> createState() => _KeychainBackupPageState();
}

class _KeychainBackupPageState extends State<KeychainBackupPage> {
  @override
  void initState() {
    super.initState();
    // Initialize state once during widget creation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KeychainCubit>().updateState(
            keyChainFlow: widget._pState,
            backupKey: widget.backupKey,
            backupData: widget.backup,
          );
    });
  }

  @override
  void dispose() {
    // Reset state when leaving the page
    context.read<KeychainCubit>().resetState();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: createBackupSettingsCubit(),
      child: _Screen(
        backupKey: widget.backupKey,
        backup: widget.backup,
        pState: widget._pState,
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({this.backupKey, required this.backup, required this.pState});

  final String? backupKey;
  final BullBackup backup;
  final KeyChainFlow pState;
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
                  selectedKeyChainFlow: pState,
                ),
              );
            }
          },
        ),
        BlocListener<KeychainCubit, KeychainState>(
          listenWhen: (previous, current) =>
              previous.isSecretConfirmed != current.isSecretConfirmed ||
              previous.secretStatus != current.secretStatus ||
              (previous.torStatus != current.torStatus &&
                  current.torStatus != TorStatus.connecting) ||
              previous.error != current.error,
          listener: (context, state) {
            if (state.hasError) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => _ErrorDialog(
                  error: state.error,
                  selectedKeyChainFlow: state.selectedKeyChainFlow,
                ),
              );
            }
            if (state.torStatus == TorStatus.offline &&
                state.authInputType != AuthInputType.backupKey) {
              context.read<KeychainCubit>().updatePageState(
                    AuthInputType.backupKey,
                    state.selectedKeyChainFlow,
                  );
              return;
            }

            // Only call secureKey if confirmed and not already processing
            if (state.isSecretConfirmed &&
                !state.loading &&
                !state.hasError &&
                state.secretStatus == SecretStatus.initial &&
                state.torStatus == TorStatus.online) {
              // Prevent multiple calls
              if (!state.isSecretConfirmed) return;
              context.read<KeychainCubit>().secureKey();
              return; // Exit early after triggering secureKey
            }

            if (state.selectedKeyChainFlow == KeyChainFlow.delete &&
                state.secretStatus == SecretStatus.deleted &&
                !state.loading &&
                !state.hasError) {
              context.read<KeychainCubit>().clearSensitive();

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => _SuccessDialog(
                  selectedKeyChainFlow: pState,
                ),
              );
            }

            if (state.isSecretConfirmed &&
                !state.loading &&
                !state.hasError &&
                state.secretStatus == SecretStatus.initial) {
              context.read<KeychainCubit>().secureKey();
            }

            if (state.secretStatus == SecretStatus.stored &&
                !state.loading &&
                !state.hasError) {
              context.read<KeychainCubit>().clearSensitive();
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => _SuccessDialog(
                  selectedKeyChainFlow: pState,
                ),
              );
            }
            if (state.secretStatus == SecretStatus.recovered &&
                !state.loading &&
                !state.hasError &&
                state.backupKey.isNotEmpty) {
              context.read<BackupSettingsCubit>().recoverBackup(
                    backup,
                    state.backupKey,
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
    switch (state.selectedKeyChainFlow) {
      case KeyChainFlow.recovery:
        return _RecoveryPage(
          key: const ValueKey('recovery'),
          authInputType: state.authInputType,
        );
      case KeyChainFlow.enter:
        return _EnterPage(
          key: const ValueKey('enter'),
          authInputType: state.authInputType,
        );
      case KeyChainFlow.confirm:
        return _ConfirmPage(
          key: const ValueKey('confirm'),
          authInputType: state.authInputType,
        );
      case KeyChainFlow.delete:
        return _DeletePage(
          key: const ValueKey('delete'),
          authInputType: state.authInputType,
        );
    }
  }
}

/// Shared layout widget for all pages
class _PageLayout extends StatelessWidget {
  const _PageLayout({
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
        padding: const EdgeInsets.symmetric(horizontal: _kHorizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// Shared input section widget
class _InputSection extends StatelessWidget {
  const _InputSection({required this.authInputType});

  final AuthInputType authInputType;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (authInputType == AuthInputType.pin) ...[
          _PinField(),
          const KeyPad(),
        ] else
          _PasswordField(),
      ],
    );
  }
}

// Optimize page type widgets
class _EnterPage extends StatelessWidget {
  const _EnterPage({super.key, required this.authInputType});
  final AuthInputType authInputType;

  @override
  Widget build(BuildContext context) {
    return _PageLayout(
      bottomChild: _SetButton(authInputType: authInputType),
      children: [
        const Gap(_kGapXLarge),
        const _TitleText(),
        const Gap(_kGapSmall),
        const _SubtitleText(),
        const Gap(_kGapXLarge),
        _InputSection(authInputType: authInputType),
        const Gap(_kGapLarge),
      ],
    );
  }
}

class _ConfirmPage extends StatelessWidget {
  const _ConfirmPage({super.key, required this.authInputType});
  final AuthInputType authInputType;

  @override
  Widget build(BuildContext context) {
    return _PageLayout(
      bottomChild: _ConfirmButton(authInputType: authInputType),
      bottomHeight: MediaQuery.of(context).size.height * 0.11,
      children: [
        const Gap(20),
        const _ConfirmTitleText(),
        const Gap(_kGapSmall),
        const _ConfirmSubtitleText(),
        const Gap(48),
        _InputSection(authInputType: authInputType),
        const Gap(24),
      ],
    );
  }
}

class _RecoveryPage extends StatelessWidget {
  const _RecoveryPage({super.key, required this.authInputType});
  final AuthInputType authInputType;

  @override
  Widget build(BuildContext context) {
    return _PageLayout(
      bottomChild: _RecoverButton(authInputType: authInputType),
      bottomHeight: MediaQuery.of(context).size.height * 0.16,
      children: [
        const Gap(_kGapXLarge),
        BBText.titleLarge(
          'Enter Recovery ${_getInputTypeText(authInputType)}',
          textAlign: TextAlign.center,
          isBold: true,
        ),
        const Gap(_kGapSmall),
        BBText.bodySmall(
          'Enter the ${_getInputTypeText(authInputType).toLowerCase()} you used to backup your keychain',
          textAlign: TextAlign.center,
        ),
        const Gap(_kGapXLarge),
        _InputSection(authInputType: authInputType),
        const Gap(_kGapLarge),
      ],
    );
  }

  String _getInputTypeText(AuthInputType type) {
    switch (type) {
      case AuthInputType.pin:
        return 'PIN';
      case AuthInputType.password:
        return 'Password';
      case AuthInputType.backupKey:
        return 'Key';
    }
  }
}

class _DeletePage extends StatelessWidget {
  const _DeletePage({super.key, required this.authInputType});
  final AuthInputType authInputType;

  @override
  Widget build(BuildContext context) {
    return _PageLayout(
      bottomChild: _DeleteButton(authInputType: authInputType),
      bottomHeight: MediaQuery.of(context).size.height * 0.11,
      children: [
        const Gap(_kGapXLarge),
        const BBText.titleLarge(
          'Delete Backup Key',
          textAlign: TextAlign.center,
          isBold: true,
        ),
        const Gap(_kGapSmall),
        BBText.bodySmall(
          'Enter your ${authInputType == AuthInputType.pin ? 'PIN' : 'password'} to delete this backup key',
          textAlign: TextAlign.center,
        ),
        const Gap(_kGapXLarge),
        _InputSection(authInputType: authInputType),
        const Gap(_kGapLarge),
      ],
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
          previous.authInputType != current.authInputType ||
          previous.backupKey != current.backupKey ||
          previous.error != current.error,
      builder: (context, state) {
        final isBackupKeyMode = state.authInputType == AuthInputType.backupKey;
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
mixin _ButtonLogicMixin {
  void handleServerCheck(BuildContext context, VoidCallback onSuccess) {
    context.read<KeychainCubit>().keyServerStatus();
    final state = context.read<KeychainCubit>().state;
    if (state.canStoreKey) onSuccess();
  }

  Widget buildServerDownMessage() {
    return const BBText.bodySmall(
      'Server is currently unavailable.\nPlease use your backup key.',
      textAlign: TextAlign.center,
      isRed: true,
    );
  }
}

class _SetButton extends StatelessWidget with _ButtonLogicMixin {
  final AuthInputType authInputType;
  const _SetButton({required this.authInputType});
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
              if (authInputType == AuthInputType.pin) {
                cubit.updatePageState(
                  AuthInputType.password,
                  KeyChainFlow.enter,
                );
              } else {
                cubit.updatePageState(
                  AuthInputType.pin,
                  KeyChainFlow.enter,
                );
              }
            },
            child: BBText.bodySmall(
              authInputType == AuthInputType.pin
                  ? 'Use a password instead of a pin'
                  : 'Use a PIN instead of a password',
              isBold: true,
            ),
          ),
          const Gap(5),
          BBButton.withColour(
            fillWidth: true,
            label:
                'Set ${authInputType == AuthInputType.pin ? 'PIN' : 'password'}',
            disabled: !canStoreKey,
            onPressed: () {
              if (canStoreKey) context.read<KeychainCubit>().confirmPressed();
            },
          ),
        ],
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget with _ButtonLogicMixin {
  const _ConfirmButton({required this.authInputType});
  final AuthInputType authInputType;
  @override
  Widget build(BuildContext context) {
    final canStoreKey =
        context.select((KeychainCubit x) => x.state.canStoreKey);
    final err = context.select((KeychainCubit x) => x.state.error);

    if (err.isNotEmpty && authInputType == AuthInputType.password) {
      return Center(child: BBText.errorSmall(err));
    }
    return BBButton.withColour(
      fillWidth: true,
      onPressed: () {
        if (canStoreKey) context.read<KeychainCubit>().confirmPressed();
      },
      leftIcon: Icons.arrow_forward,
      label:
          'Confirm ${authInputType == AuthInputType.pin ? 'PIN' : 'password'}',
      disabled: !canStoreKey,
    );
  }
}

class _RecoverButton extends StatelessWidget with _ButtonLogicMixin {
  const _RecoverButton({required this.authInputType});
  final AuthInputType authInputType;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KeychainCubit, KeychainState>(
      buildWhen: (previous, current) =>
          previous.canRecoverKey != current.canRecoverKey ||
          previous.loading != current.loading ||
          previous.selectedKeyChainFlow != current.selectedKeyChainFlow ||
          previous.keyServerUp != current.keyServerUp,
      builder: (context, state) {
        final canRecover = authInputType == AuthInputType.backupKey
            ? state.canRecoverWithBckupKey
            : state.canRecoverKey;

        // Show only backup key option if server is down
        if (!state.keyServerUp && authInputType != AuthInputType.backupKey) {
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
            // Always show PIN/password switch
            InkWell(
              onTap: () => _switchInputType(context),
              child: BBText.bodySmall(_getSwitchButtonText(), isBold: true),
            ),
            const Gap(10),
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
    final newType = authInputType == AuthInputType.pin
        ? AuthInputType.password
        : AuthInputType.pin;
    cubit.updatePageState(newType, KeyChainFlow.recovery);
  }

  void _switchToBackupKey(BuildContext context) {
    context.read<KeychainCubit>().updatePageState(
          AuthInputType.backupKey,
          KeyChainFlow.recovery,
        );
  }

  String _getSwitchButtonText() {
    switch (authInputType) {
      case AuthInputType.pin:
        return 'Use a password instead of a PIN';
      case AuthInputType.password:
        return 'Use a PIN instead of a password';
      case AuthInputType.backupKey:
        return 'Use a PIN instead of a backup key';
    }
  }

  String _getInputTypeText() {
    switch (authInputType) {
      case AuthInputType.pin:
        return 'PIN';
      case AuthInputType.password:
        return 'password';
      case AuthInputType.backupKey:
        return 'backup key';
    }
  }
}

class _DeleteButton extends StatelessWidget with _ButtonLogicMixin {
  const _DeleteButton({required this.authInputType});
  final AuthInputType authInputType;

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
            child: Text(
              'Delete',
              style: context.font.bodyMedium!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
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

class _DialogBase extends StatelessWidget {
  const _DialogBase({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onButtonPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onButtonPressed;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colour.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(_kGapLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: context.colour.primary,
              size: 48,
            ),
            const Gap(_kGapMedium),
            BBText.title(title, textAlign: TextAlign.center, isBold: true),
            const Gap(_kGapSmall),
            BBText.bodySmall(message, textAlign: TextAlign.center),
            const Gap(_kGapLarge),
            BBButton.withColour(
              label: buttonText,
              onPressed: onButtonPressed,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({required this.selectedKeyChainFlow});

  final KeyChainFlow selectedKeyChainFlow;

  @override
  Widget build(BuildContext context) {
    String title;
    String message;
    String route;
    dynamic extra;

    if (selectedKeyChainFlow == KeyChainFlow.recovery) {
      title = 'Recovery Successful';
      message = 'Your wallet has been recovered successfully';
      route = '/home';
    } else if (selectedKeyChainFlow == KeyChainFlow.enter ||
        selectedKeyChainFlow == KeyChainFlow.confirm) {
      title = 'Backup Successful';
      message =
          'Your wallet has been backed up successfully \n Please test your backup';
      route = '/wallet-settings/backup-settings/recover-options/encrypted';
      extra = false;
    } else {
      title = 'Backup Key Deleted';
      message = 'Your backup key has been permanently deleted';
      route = '/home';
    }

    return _DialogBase(
      icon: Icons.check_circle_outline,
      title: title,
      message: message,
      buttonText: 'Continue',
      onButtonPressed: () {
        // Reset state before navigation
        context.read<KeychainCubit>().resetState();
        Navigator.of(context).pop();
        if (extra != null) {
          context.push(route, extra: extra);
        } else {
          context.go(route);
        }
      },
    );
  }
}

class _ErrorDialog extends StatelessWidget {
  const _ErrorDialog({
    required this.error,
    this.selectedKeyChainFlow = KeyChainFlow.enter,
  });
  final String error;
  final KeyChainFlow selectedKeyChainFlow;
  @override
  Widget build(BuildContext context) {
    return _DialogBase(
      icon: Icons.error_outline,
      title: selectedKeyChainFlow == KeyChainFlow.enter
          ? 'Backup failed'
          : selectedKeyChainFlow == KeyChainFlow.recovery
              ? 'Recovery failed'
              : 'Delete failed',
      message: error,
      buttonText: 'Continue',
      onButtonPressed: () {
        context.read<KeychainCubit>().clearError();
        Navigator.of(context).pop();
      },
    );
  }
}

/// Text Widgets
class _TitleText extends StatelessWidget {
  const _TitleText();

  @override
  Widget build(BuildContext context) {
    final (inputState, type) = context.select(
      (KeychainCubit x) =>
          (x.state.selectedKeyChainFlow, x.state.authInputType),
    );
    final text = inputState == KeyChainFlow.enter
        ? 'Choose a backup ${type == AuthInputType.pin ? 'PIN' : 'password'}'
        : 'Confirm backup ${type == AuthInputType.pin ? 'PIN' : 'password'}';
    return BBText.titleLarge(textAlign: TextAlign.center, text, isBold: true);
  }
}

class _ConfirmTitleText extends StatelessWidget {
  const _ConfirmTitleText();

  @override
  Widget build(BuildContext context) {
    final (selectedKeyChainFlow, authInputType) = context.select(
        (KeychainCubit x) =>
            (x.state.selectedKeyChainFlow, x.state.authInputType));
    final text =
        'Confirm backup ${authInputType == AuthInputType.pin ? 'PIN' : 'password'}';

    return BBText.titleLarge(textAlign: TextAlign.center, text, isBold: true);
  }
}

class _ConfirmSubtitleText extends StatelessWidget {
  const _ConfirmSubtitleText();

  @override
  Widget build(BuildContext context) {
    final authInputType =
        context.select((KeychainCubit x) => x.state.authInputType);
    return BBText.bodySmall(
      textAlign: TextAlign.center,
      'Enter the ${authInputType == AuthInputType.pin ? 'PIN' : 'password'} again to confirm',
    );
  }
}

class _SubtitleText extends StatelessWidget {
  const _SubtitleText();

  @override
  Widget build(BuildContext context) {
    final authInputType =
        context.select((KeychainCubit x) => x.state.authInputType);
    final text =
        'You must memorize this ${authInputType == AuthInputType.pin ? 'PIN' : 'password'} to recover access to your wallet. It must be at least ${KeychainCubit.pinMin} digits.';
    return BBText.bodySmall(textAlign: TextAlign.center, text);
  }
}
