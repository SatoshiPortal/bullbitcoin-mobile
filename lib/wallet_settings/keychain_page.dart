import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/page_template.dart';
import 'package:bb_mobile/_ui/toast.dart';
import 'package:bb_mobile/styles.dart';
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
    required this.backupKey,
    required this.backupId,
    required this.backupSalt,
  });

  final String backupSalt;
  final String backupKey;
  final String backupId;
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => KeychainCubit(),
      child: _Screen(
        backupId: backupId,
        backupKey: backupKey,
        backupSalt: backupSalt,
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({
    required this.backupKey,
    required this.backupId,
    required this.backupSalt,
  });
  final String backupSalt;
  final String backupKey;
  final String backupId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<KeychainCubit, KeychainState>(
          listenWhen: (previous, current) => previous.saved != current.saved,
          listener: (context, state) {
            if (state.saved) {
              context.read<KeychainCubit>().clearSensitive();
              context.go('/home');
            }
          },
        ),
        BlocListener<KeychainCubit, KeychainState>(
          listenWhen: (previous, current) =>
              previous.pinConfirmed != current.pinConfirmed ||
              previous.passwordConfirmed != current.passwordConfirmed,
          listener: (context, state) {
            if ((state.pinConfirmed || state.passwordConfirmed) &&
                !state.saving &&
                state.error.isEmpty) {
              context
                  .read<KeychainCubit>()
                  .secureKey(backupId, backupKey, backupSalt);
            }
            if (state.error.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                context.showToast(state.error),
              );
            }
          },
        ),
      ],
      child: BlocBuilder<KeychainCubit, KeychainState>(
        builder: (context, state) {
          if (state.saving) return const _LoadingView();

          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              elevation: 0,
              flexibleSpace: BBAppBar(
                text: 'Keychain Backup',
                onBack: () {
                  //TODO; clear sensitive data
                  context.pop();
                },
              ),
            ),
            body: AnimatedSwitcher(
              duration: 300.ms,
              child: state.pageState == KeyChainPageState.enter
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
        child: CircularProgressIndicator(
          color: context.colour.onSurface,
        ),
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
      bottomChildHeight: MediaQuery.of(context).size.height * 0.1,
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
              const _PinField(),
              const KeyPad(),
            ] else
              const _PasswordField(),
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
                const _PinField(),
                const KeyPad(),
              ] else
                const _PasswordField(),
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
      bottomChildHeight: MediaQuery.of(context).size.height * 0.1,
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
  const _PinField();

  @override
  Widget build(BuildContext context) {
    final pin = context.select((KeychainCubit x) => x.state.displayPin());
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 40),
          Expanded(
            child: Center(
              child: BBText.titleLarge(
                pin,
                isBold: true,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              iconSize: 32,
              color: pin.isEmpty
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
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField();

  @override
  Widget build(BuildContext context) {
    final password = context.select((KeychainCubit x) => x.state.password);
    // final err = context.select((KeychainCubit x) => x.state.err);
    return BBTextInput.big(
      value: password,
      onChanged: (value) {
        context.read<KeychainCubit>().passwordChanged(value);
      },
      hint: 'Enter your password',
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
  const _SetButton({required this.inputType});
  final KeyChainInputType inputType;
  @override
  Widget build(BuildContext context) {
    final showButton =
        context.select((KeychainCubit x) => x.state.showButton());

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              final cubit = context.read<KeychainCubit>();
              if (inputType == KeyChainInputType.pin) {
                cubit.changeInputType(KeyChainInputType.password);
              } else {
                cubit.changeInputType(KeyChainInputType.pin);
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
    Widget dialogContent = Padding(
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
                : 'Your wallet has been backed up successfully',
            textAlign: TextAlign.center,
          ),
          const Gap(24),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/home');
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
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: dialogContent,
    );
  }
}

class _ErrorDialog extends StatelessWidget {
  const _ErrorDialog({required this.error});
  final String error;

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
              'Recovery Failed',
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
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
