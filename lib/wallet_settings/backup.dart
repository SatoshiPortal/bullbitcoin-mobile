import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/popup_border.dart';
import 'package:bb_mobile/_ui/templates/headers.dart';
import 'package:bb_mobile/_ui/word_grid.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet_settings/bloc/state.dart';
import 'package:bb_mobile/wallet_settings/bloc/wallet_settings_cubit.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class TestBackupScreen extends StatelessWidget {
  const TestBackupScreen({super.key});

  static Future openPopup(BuildContext context) {
    final settings = context.read<WalletSettingsCubit>();
    final wallet = context.read<WalletBloc>();
    // settings.clearnMnemonic();
    settings.loadBackupClicked();

    return showMaterialModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: wallet),
          BlocProvider.value(value: settings),
        ],
        child: BlocListener<WalletSettingsCubit, WalletSettingsState>(
          listenWhen: (previous, current) => previous.backupTested != current.backupTested,
          listener: (context, state) async {
            if (state.backupTested) {
              await Future.delayed(3.seconds);
              context.pop();
            }
          },
          child: const PopUpBorder(
            child: TestBackupScreen(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mnemonic = context.select(
      (WalletSettingsCubit cubit) => cubit.state.mnemonic,
    );
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: BBHeader.popUpCenteredText(
                text: 'Test Backup',
                isLeft: true,
              ),
            ),
            const Gap(16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: BBText.bodySmall(
                'Your seed words are displayed below in a randomized order. Tap on the words in the correct sequence to prove you’ve done your backup correctly.',
              ),
            ),
            // const Gap(4),
            // Padding(
            //   padding: const EdgeInsets.only(left: 16.0),
            //   child: CenterLeft(
            //     child: BBButton.text(
            //       label: 'Reset Order',
            //       onPressed: () => context.read<WalletSettingsCubit>().loadBackupClicked(),
            //     ),
            //   ),
            // ),
            const Gap(32),
            if (mnemonic.length == 12)
              for (var i = 0; i < 6; i++)
                Row(
                  children: [
                    for (var j = 0; j < 2; j++)
                      BackupTestItemWord(
                        index: i == 0 ? j : i * 2 + j,
                        // isSelected: context
                        //     .select<WalletSettingsCubit>()
                        //     .state
                        //     .shuffleIsSelected(i == 0 ? j : i * 2 + j),
                      ),
                  ],
                ),
            if (mnemonic.length == 24)
              for (var i = 0; i < 12; i++)
                Row(
                  children: [
                    for (var j = 0; j < 2; j++)
                      BackupTestItemWord(
                        index: i == 0 ? j : i * 2 + j,
                        // isSelected: context
                        //     .select<WalletSettingsCubit>()
                        //     .state
                        //     .shuffleIsSelected(i == 0 ? j : i * 2 + j),
                      ),
                  ],
                ),
            const Gap(16),
            const TestBackupPassField(),
            const TestBackupConfirmButton(),
            const Gap(24),
            Center(
              child: SizedBox(
                width: 200,
                child: BBButton.text(
                  onPressed: () {
                    context.pop();
                    BackupScreen.openPopup(context);
                  },
                  centered: true,
                  label: 'View backup',
                ),
              ),
            ),
            const Gap(60),
          ],
        ),
      ),
    );
  }
}

class BackupTestItemWord extends StatelessWidget {
  const BackupTestItemWord({
    super.key,
    required this.index,
  });

  final int index;

  @override
  Widget build(BuildContext context) {
    final mnemonic = context.select(
      (WalletSettingsCubit cubit) => cubit.state.mnemonic,
    );

    final (word, isSelected, actualIdx) = context.select(
      (WalletSettingsCubit _) => _.state.shuffleElementAt(index),
    );

    final padLeft = (isSelected && actualIdx.toString().length == 2) ? 12.0 : 16.0;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 0, 4, 24),
        child: InkWell(
          onTap: () {
            if (mnemonic.length == 12)
              context.read<WalletSettingsCubit>().wordClicked(index);
            else {
              context.read<WalletSettingsCubit>().word24Clicked(index);
            }
          },
          child: Stack(
            children: [
              AnimatedContainer(
                duration: 0.3.seconds,
                width: double.infinity,
                height: 40,
                padding: EdgeInsets.only(left: padLeft),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(80),
                  border: Border.all(
                    color: context.colour.surface,
                  ),
                  color: isSelected ? context.colour.primary : context.colour.onBackground,
                ),
                child: CenterLeft(
                  child: BBText.body(
                    isSelected ? '${actualIdx + 1}' : '?',
                    onSurface: true,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Container(
                  padding: const EdgeInsets.only(left: 16),
                  width: double.infinity,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(80),
                    border: Border.all(
                      color: context.colour.surface,
                    ),
                    color: context.colour.background,
                  ),
                  child: CenterLeft(child: BBText.body(word)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TestBackupPassField extends HookWidget {
  const TestBackupPassField({super.key});

  @override
  Widget build(BuildContext context) {
    final hasPassphrase = context.select((WalletBloc x) => x.state.wallet!.hasPassphrase());

    if (!hasPassphrase) return const SizedBox.shrink();

    final text = context.select((WalletSettingsCubit x) => x.state.testBackupPassword);

    return Padding(
      padding: const EdgeInsets.only(
        left: 32.0,
        right: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(16),
          const BBText.body(
            '   Enter passphrase',
          ),
          const Gap(8),
          BBTextInput.big(
            value: text,
            onChanged: (t) {
              context.read<WalletSettingsCubit>().changePassword(t);
            },
          ),
        ],
      ),
    );
  }
}

class TestBackupConfirmButton extends StatelessWidget {
  const TestBackupConfirmButton();

  @override
  Widget build(BuildContext context) {
    final testing = context.select((WalletSettingsCubit cubit) => cubit.state.testingBackup);
    final err = context.select((WalletSettingsCubit cubit) => cubit.state.errTestingBackup);
    final tested = context.select((WalletSettingsCubit cubit) => cubit.state.backupTested);

    return Column(
      children: [
        if (err.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: BBText.error(
                err,
              ).animate().fadeIn(),
            ),
          ),
        const Gap(40),
        if (tested)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: const BBText.body(
                  'Success! Your backup test worked.',
                ).animate(delay: 300.ms).fadeIn(),
              ),
            ),
          )
        else
          Center(
            child: SizedBox(
              width: 300,
              child: BBButton.bigRed(
                disabled: testing,
                loading: testing,
                filled: true,
                onPressed: () => context.read<WalletSettingsCubit>().testBackupClicked(),
                label: 'Test Backup',
              ),
            ),
          ),
      ],
    );
  }
}

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  static Future openPopup(
    BuildContext context,
  ) {
    final wallet = context.read<WalletBloc>();
    final walletSettings = context.read<WalletSettingsCubit>();
    walletSettings.loadBackupClicked();

    return showMaterialModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: wallet),
          BlocProvider.value(value: walletSettings),
        ],
        child: const PopUpBorder(
          child: BackupScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mnemonic = context.select(
      (WalletSettingsCubit cubit) => cubit.state.mnemonic,
    );

    final password = context.select(
      (WalletSettingsCubit cubit) => cubit.state.password,
    );

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: BBHeader.popUpCenteredText(
                text: 'Backup',
                isLeft: true,
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: BBText.bodySmall(
                'Write down these 12/24 words somewhere safe, on a piece of paper or engraved in metal. You’ll need them if you lose your phone or access to the Bull Bitcoin app. Don’t store them on a phone or computer.',
              ),
            ),
            const Gap(8),
            if (mnemonic.length == 12) WordGrid(mne: mnemonic) else WordGrid(mne: mnemonic),
            if (password.isNotEmpty) ...[
              const Gap(24),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: BBText.bodySmall(
                  'This wallet backup is protected by an addditional BIP39 passphrase. If you lose the passphrase, you will not be able to recover access to the wallet. Write down your passphrase and your backup words separately: anybody that has both your passphrase and your backup words can steal your Bitcoin.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: BBText.body(
                  'Passphrase: $password',
                ),
              ),
            ] else ...[
              const Gap(24),
              const Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: BBText.bodySmall(
                  'This wallet backup is not protected by an additional BIP39 passphrase. Anybody that finds your backup words can steal your Bitcoin. You can add a passphrase when creating a new wallet',
                ),
              ),
            ],
            const Gap(48),
            Center(
              child: SizedBox(
                width: 200,
                child: BBButton.bigRed(
                  onPressed: () {
                    context.pop();
                  },
                  label: 'Okay',
                ),
              ),
            ),
            const Gap(24),
            Center(
              child: SizedBox(
                width: 200,
                child: BBButton.text(
                  onPressed: () {
                    context.pop();
                    TestBackupScreen.openPopup(context);
                  },
                  centered: true,
                  label: 'Test backup',
                ),
              ),
            ),
            const Gap(48),
          ],
        ),
      ),
    );
  }
}

// class BackupTestTextField extends StatefulWidget {
//   const BackupTestTextField({super.key, required this.index});

//   final int index;

//   @override
//   State<BackupTestTextField> createState() => _BackupTestTextFieldState();
// }

// class _BackupTestTextFieldState extends State<BackupTestTextField> {
//   @override
//   Widget build(BuildContext context) {
//     final text = context.select(
//       (WalletSettingsCubit cubit) => cubit.state.mnemonic.elementAt(widget.index),
//     );

//     return Expanded(
//       child: Container(
//         margin: const EdgeInsets.fromLTRB(4, 0, 4, 8),
//         height: 36,
//         child: Row(
//           children: [
//             SizedBox(
//               width: 20,
//               child: BBText.body(
//                 '${widget.index + 1}',
//                 textAlign: TextAlign.right,
//               ),
//             ),
//             const Gap(8),
//             Expanded(
//               child: BBTextInput.small(
//                 value: text,
//                 onChanged: (value) {
//                   context.read<WalletSettingsCubit>().wordChanged(widget.index, value);
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
