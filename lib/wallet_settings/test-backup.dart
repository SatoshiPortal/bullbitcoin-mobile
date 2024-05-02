import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet_settings/bloc/wallet_settings_cubit.dart';
import 'package:bb_mobile/wallet_settings/listeners.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class TestBackupPage extends StatelessWidget {
  const TestBackupPage({
    super.key,
    required this.walletBloc,
    required this.walletSettings,
  });

  final WalletBloc walletBloc;
  final WalletSettingsCubit walletSettings;

  @override
  Widget build(BuildContext context) {
    walletSettings.loadBackupClicked();

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: walletBloc),
        BlocProvider.value(value: walletSettings),
      ],
      child: TestBackupListener(
        child: Builder(
          builder: (context) {
            return PopScope(
              canPop: false,
              onPopInvoked: (canPop) {
                context.go('/home');
              },
              child: Scaffold(
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  flexibleSpace: BBAppBar(
                    text: 'Test Backup',
                    onBack: () {
                      context.pop();
                      context.read<WalletSettingsCubit>().resetBackupTested();
                    },
                  ),
                ),
                body: const TestBackupScreen(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class TestBackupScreen extends StatelessWidget {
  const TestBackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mnemonic =
        context.select((WalletSettingsCubit cubit) => cubit.state.mnemonic);
    final tested =
        context.select((WalletSettingsCubit cubit) => cubit.state.backupTested);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!tested) ...[
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
            ],
            const Gap(48),

            const TestBackupConfirmButton(),
            const Gap(40),

            // const Gap(24),
            // Center(
            //   child: SizedBox(
            //     width: 200,
            //     child: BBButton.text(
            //       onPressed: () {
            //         context
            //           ..pop()
            //           ..push(
            //             '/wallet-settings/backup',
            //             extra: (
            //               context.read<WalletBloc>(),
            //               context.read<WalletSettingsCubit>(),
            //             ),
            //           );
            //         // context.pop();
            //         // BackupScreen.openPopup(context);
            //       },
            //       centered: true,
            //       label: 'View backup',
            //     ),
            //   ),
            // ),
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

    final padLeft =
        (isSelected && actualIdx.toString().length == 2) ? 12.0 : 16.0;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 0, 4, 24),
        child: InkWell(
          borderRadius: BorderRadius.circular(80),
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
                  color: isSelected
                      ? context.colour.primary
                      : context.colour.onBackground,
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
    final tested =
        context.select((WalletSettingsCubit cubit) => cubit.state.backupTested);
    if (tested) return const SizedBox.shrink();

    final hasPassphrase =
        context.select((WalletBloc x) => x.state.wallet!.hasPassphrase());

    if (!hasPassphrase) return const SizedBox.shrink();

    final text =
        context.select((WalletSettingsCubit x) => x.state.testBackupPassword);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
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
    final testing = context
        .select((WalletSettingsCubit cubit) => cubit.state.testingBackup);
    final tested =
        context.select((WalletSettingsCubit cubit) => cubit.state.backupTested);

    return Column(
      children: [
        if (tested)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: const BBText.titleLarge(
                  'Success!\nYour backup test worked.',
                  isBold: true,
                  textAlign: TextAlign.center,
                ).animate(delay: 300.ms).fadeIn(),
              ),
            ),
          )
        else
          Center(
            child: SizedBox(
              width: 250,
              child: BBButton.big(
                disabled: testing,
                loading: testing,
                filled: true,
                onPressed: () =>
                    context.read<WalletSettingsCubit>().testBackupClicked(),
                label: 'Test Backup',
              ),
            ),
          ),
      ],
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
