import 'dart:convert';

import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/page_template.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet_settings/bloc/backup_settings_cubit.dart';
import 'package:bb_mobile/wallet_settings/bloc/backup_settings_state.dart';
import 'package:bb_mobile/wallet_settings/bloc/keychain_cubit.dart';
import 'package:bb_mobile/wallet_settings/bloc/keychain_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class KeychainBackupPage extends StatelessWidget {
  const KeychainBackupPage({
    super.key,
    this.backupKey,
    required this.backup,
  });

  final String? backupKey;
  final Map<String, dynamic> backup;
  @override
  Widget build(BuildContext context) {
    String? backupId;
    String? backupSalt;

    if (backupKey != null && backupKey!.isNotEmpty) {
      backupId = backup['id']?.toString();
      backupSalt = backup['salt']?.toString();
    } else {
      final encryptedData =
          jsonDecode(backup["encrypted"] as String) as Map<String, dynamic>;
      backupId = encryptedData["id"]?.toString();
      backupSalt = encryptedData["salt"] as String?;
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider<KeychainCubit>(
          create: (context) => KeychainCubit()
            ..setChainState(
              (backupKey == null || backupKey!.isEmpty)
                  ? KeyChainPageState.recovery
                  : KeyChainPageState.enter,
              backupId ?? '',
              backupKey,
              backupSalt ?? '',
            ),
        ),
        BlocProvider.value(
          value: createBackupSettingsCubit(),
        ),
      ],
      child: _Screen(
        backupKey: backupKey,
        encryptedBackup: backup,
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({
    this.backupKey,
    required this.encryptedBackup,
  });

  final String? backupKey;
  final Map<String, dynamic> encryptedBackup;
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
                builder: (context) => const _SuccessDialog(isRecovery: true),
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
            if (state.isSecretConfirmed &&
                !state.loading &&
                !state.hasError &&
                state.keySecretState != KeySecretState.saved) {
              context.read<KeychainCubit>().secureKey();
            }

            if (state.keySecretState == KeySecretState.saved &&
                !state.loading &&
                !state.hasError) {
              context.read<KeychainCubit>().clearSensitive();
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const _SuccessDialog(isRecovery: false),
              );
            }

            if (state.keySecretState == KeySecretState.recovered &&
                !state.loading &&
                !state.hasError) {
              if (encryptedBackup.isNotEmpty) {
                context.read<BackupSettingsCubit>().recoverWithKeyServer(
                      jsonEncode(encryptedBackup),
                      state.backupKey,
                    );
              }
            }

            if (state.hasError) {
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
      ],
      child: BlocBuilder<KeychainCubit, KeychainState>(
        builder: (context, state) {
          if (state.loading) {
            return const _LoadingView();
          }

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
              child: state.pageState == KeyChainPageState.recovery
                  ? _RecoveryPage(
                      key: const ValueKey('recovery'),
                      inputType: state.inputType,
                    )
                  : state.pageState == KeyChainPageState.enter
                      ? _EnterPage(
                          key: const ValueKey('enter'),
                          inputType: state.inputType,
                        )
                      : _ConfirmPage(
                          key: const ValueKey('confirm'),
                          inputType: state.inputType,
                        ),
            ),
          );
        },
      ),
    );
  }
}

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

class _EnterPage extends StatelessWidget {
  const _EnterPage({super.key, required this.inputType});
  final KeyChainInputType inputType;

  @override
  Widget build(BuildContext context) {
    return StackedPage(
      bottomChildHeight: MediaQuery.of(context).size.height * 0.12,
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
      bottomChildHeight: MediaQuery.of(context).size.height * 0.12,
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
      bottomChildHeight: MediaQuery.of(context).size.height * 0.12,
      bottomChild: _RecoverButton(inputType: inputType),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(50),
            BBText.titleLarge(
              'Enter Recovery ${inputType == KeyChainInputType.pin ? 'PIN' : 'Password'}',
              textAlign: TextAlign.center,
              isBold: true,
            ),
            const Gap(8),
            BBText.bodySmall(
              'Enter the ${inputType == KeyChainInputType.pin ? 'PIN' : 'password'} you used to backup your keychain',
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
                  child: BBText.titleLarge(
                    state.displayPin(),
                    isBold: true,
                  ),
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
            child: Center(
              child: BBText.errorSmall(error),
            ),
          ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.select((KeychainCubit x) => x.state);
    final error = state.getValidationError();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBTextInput.bigWithIcon(
          value: state.secret,
          onChanged: (value) =>
              context.read<KeychainCubit>().updateInput(value),
          obscure: state.obscure,
          hint: 'Enter your password',
          rightIcon: Icon(
            state.obscure ? Icons.visibility_off : Icons.visibility,
            color: context.colour.onPrimaryContainer,
          ),
          onRightTap: () => context.read<KeychainCubit>().clickObscure(),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 8),
            child: BBText.errorSmall(error),
          ),
      ],
    );
  }
}

class _TitleText extends StatelessWidget {
  const _TitleText();

  @override
  Widget build(BuildContext context) {
    final (inputState, type) = context
        .select((KeychainCubit x) => (x.state.pageState, x.state.inputType));
    final text = inputState == KeyChainPageState.enter
        ? 'Choose a backup ${type == KeyChainInputType.pin ? 'PIN' : 'password'}'
        : 'Confirm backup ${type == KeyChainInputType.pin ? 'PIN' : 'password'}';
    return BBText.titleLarge(
      textAlign: TextAlign.center,
      text,
      isBold: true,
    );
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

    return BBText.titleLarge(
      textAlign: TextAlign.center,
      text,
      isBold: true,
    );
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
        'You must memorize this ${inputType == KeyChainInputType.pin ? 'PIN' : 'password'} to recover access to your wallet. It must be at least 6 digits.';
    return BBText.bodySmall(
      textAlign: TextAlign.center,
      text,
    );
  }
}

class _SetButton extends StatelessWidget {
  final KeyChainInputType inputType;
  const _SetButton({required this.inputType});
  @override
  Widget build(BuildContext context) {
    final showButton = context.select((KeychainCubit x) => x.state.showButton);
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
          FilledButton(
            onPressed: () {
              if (showButton) context.read<KeychainCubit>().confirmPressed();
            },
            style: FilledButton.styleFrom(
              backgroundColor:
                  showButton ? context.colour.shadow : context.colour.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Set ${inputType == KeyChainInputType.pin ? 'PIN' : 'password'}',
                  style: context.font.bodyMedium!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
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
    final showButton = context.select((KeychainCubit x) => x.state.showButton);
    final err = context.select((KeychainCubit x) => x.state.error);

    if (err.isNotEmpty && inputType == KeyChainInputType.password) {
      return Center(
        child: BBText.errorSmall(
          err,
        ),
      );
    }
    return FilledButton(
      onPressed: () {
        if (showButton) context.read<KeychainCubit>().confirmPressed();
      },
      style: FilledButton.styleFrom(
        backgroundColor:
            showButton ? context.colour.shadow : context.colour.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Confirm ${inputType == KeyChainInputType.pin ? 'PIN' : 'password'}',
            style: context.font.bodyMedium!.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward,
            color: Colors.white,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class _RecoverButton extends StatelessWidget {
  const _RecoverButton({required this.inputType});
  final KeyChainInputType inputType;

  @override
  Widget build(BuildContext context) {
    final canRecover = context.select((KeychainCubit x) => x.state.canRecover);
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
                  KeyChainPageState.recovery,
                );
              } else {
                cubit.updatePageState(
                  KeyChainInputType.pin,
                  KeyChainPageState.recovery,
                );
              }
            },
            child: BBText.bodySmall(
              inputType == KeyChainInputType.pin
                  ? 'Use a password instead of a pin'
                  : 'Use a PIN instead of a password',
            ),
          ),
          const Gap(5),
          FilledButton(
            onPressed: () {
              if (canRecover) context.read<KeychainCubit>().clickRecoverKey();
            },
            style: FilledButton.styleFrom(
              backgroundColor:
                  canRecover ? context.colour.shadow : context.colour.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Recover with ${inputType == KeyChainInputType.pin ? 'PIN' : 'password'}',
                  style: context.font.bodyMedium!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
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
          onTapUp: (e) {
            setState(() {
              isRed = false;
            });
          },
          onTapDown: (e) {
            setState(() {
              isRed = true;
            });
          },
          onTapCancel: () {
            setState(() {
              isRed = false;
            });
          },
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              splashFactory: NoSplash.splashFactory,
            ),
            onPressed: () {
              SystemSound.play(SystemSoundType.click);
              HapticFeedback.mediumImpact();

              context.read<KeychainCubit>().keyPressed(widget.text);
            },
            child: BBText.titleLarge(
              widget.text,
              isBold: true,
            ),
          ).animate().blur(
                begin: const Offset(1, 1),
                end: isRed ? const Offset(2, 2) : Offset.zero,
              ),
        ),
      ),
    );
  }
}

class KeyPad extends StatelessWidget {
  const KeyPad({super.key});

  @override
  Widget build(BuildContext context) {
    final shuffledNumbers =
        context.select((KeychainCubit x) => x.state.shuffledNumbers);
    final shuffledNumberButtonList = [
      for (final i in shuffledNumbers) NumberButton(text: i.toString()),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      child: GridView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
        ),
        children: [
          for (var i = 0; i < 9; i = i + 1) shuffledNumberButtonList[i],
          Container(),
          shuffledNumberButtonList[9],
        ],
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({required this.isRecovery});
  final bool isRecovery;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: context.colour.shadow,
              size: 48,
            ),
            const Gap(16),
            BBText.title(
              isRecovery ? 'Recovery Successful' : 'Backup Successful',
              textAlign: TextAlign.center,
              isBold: true,
            ),
            const Gap(8),
            BBText.bodySmall(
              isRecovery
                  ? 'Your wallet has been recovered successfully'
                  : 'Your wallet has been backed up successfully \n Please test your backup',
              textAlign: TextAlign.center,
            ),
            const Gap(24),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go(
                  isRecovery
                      ? '/home'
                      : '/wallet-settings/backup-settings/recover-options/encrypted',
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: context.colour.shadow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Continue'),
            ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: context.colour.error,
              size: 48,
            ),
            const Gap(16),
            BBText.title(
              isRecovery ? 'Recovery Failed' : 'Backup Failed',
              textAlign: TextAlign.center,
              isBold: true,
            ),
            const Gap(8),
            BBText.bodySmall(
              error,
              textAlign: TextAlign.center,
            ),
            const Gap(24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: context.colour.shadow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Close',
                style: context.font.bodyMedium!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
