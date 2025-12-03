import 'dart:async';

import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/app_bar_widget.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/backup_test_success.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class VerifyMnemonicScreen extends StatefulWidget {
  const VerifyMnemonicScreen({super.key});

  @override
  State<VerifyMnemonicScreen> createState() => _VerifyMnemonicScreenState();
}

class _VerifyMnemonicScreenState extends State<VerifyMnemonicScreen>
    with PrivacyScreen {
  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: enableScreenPrivacy(),
      builder: (context, snapshot) {
        return BlocConsumer<TestWalletBackupBloc, TestWalletBackupState>(
          listenWhen:
              (previous, current) =>
                  (previous.reorderedMnemonic.length !=
                          current.mnemonic.length &&
                      current.reorderedMnemonic.length ==
                          current.mnemonic.length) ||
                  (previous.statusError.isEmpty &&
                      current.statusError.isNotEmpty),
          listener: (context, state) {
            if (state.statusError.isNotEmpty) {
              SnackBarUtils.showSnackBar(context, state.statusError);
              context.read<TestWalletBackupBloc>().add(const ClearError());
            } else if (state.reorderedMnemonic.length ==
                    state.mnemonic.length &&
                state.statusError.isEmpty) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const BackupTestSuccessScreen(),
                ),
              );
            }
          },
          builder: (context, state) {
            final title =
                'Test ${state.selectedWallet?.isDefault ?? false ? 'Default Wallets' : state.selectedWallet?.displayLabel ?? ''}';
            final reorderedMnemonic =
                context.watch<TestWalletBackupBloc>().state.reorderedMnemonic;
            final mnemonic =
                context.watch<TestWalletBackupBloc>().state.mnemonic;

            final nextWordNumber =
                reorderedMnemonic.isEmpty ? 1 : reorderedMnemonic.length + 1;
            final showPrompt = reorderedMnemonic.length < mnemonic.length;
            return Scaffold(
              backgroundColor: context.appColors.onSecondary,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: AppBarWidget(title: title),
              ),
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BBText(
                        'Tap the recovery words in the \nright order',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: context.font.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: 0,
                        ),
                      ),
                      const Gap(20),
                      if (showPrompt)
                        Column(
                          children: [
                            BBText(
                              'What is word number $nextWordNumber?',
                              textAlign: TextAlign.center,
                              style: context.font.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.appColors.outline,
                                letterSpacing: 0,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      else
                        BBText(
                          'You have selected all words',
                          textAlign: TextAlign.center,
                          style: context.font.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.appColors.surface,
                            letterSpacing: 0,
                            fontSize: 14,
                          ),
                        ),
                      const Gap(16),

                      const _ShuffledMnemonicGrid(),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ShuffledMnemonicGrid extends StatelessWidget {
  const _ShuffledMnemonicGrid();

  @override
  Widget build(BuildContext context) {
    final shuffledMnemonic =
        context.watch<TestWalletBackupBloc>().state.shuffledMnemonic;

    return Column(
      children: [
        for (var i = 0; i < (shuffledMnemonic.length + 1) ~/ 2; i++)
          Row(
            children: [
              Expanded(
                child: _ShuffledMnemonicWord(
                  index: i,
                  word: shuffledMnemonic[i],
                ),
              ),
              if (i + (shuffledMnemonic.length + 1) ~/ 2 <
                  shuffledMnemonic.length)
                Expanded(
                  child: _ShuffledMnemonicWord(
                    index: i + (shuffledMnemonic.length + 1) ~/ 2,
                    word:
                        shuffledMnemonic[i +
                            (shuffledMnemonic.length + 1) ~/ 2],
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
      ],
    );
  }
}

class _ShuffledMnemonicWord extends StatelessWidget {
  const _ShuffledMnemonicWord({required this.word, required this.index});
  final int index;
  final String word;

  @override
  Widget build(BuildContext context) {
    final selectedMnemonicWords =
        context.watch<TestWalletBackupBloc>().state.selectedMnemonicWords;
    final isSelected = selectedMnemonicWords.contains(index);
    final selectedWordNumber = selectedMnemonicWords.indexOf(index) + 1;

    return InkWell(
      onTap:
          isSelected
              ? null
              : () {
                context.read<TestWalletBackupBloc>().add(
                  OnWordsSelected(word: word, index: index),
                );
              },
      splashColor: context.appColors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 20),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(2.76),
          border: Border.all(color: context.appColors.surface, width: 0.69),
          boxShadow: [
            BoxShadow(
              color: context.appColors.surface,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        height: 41,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                );
              },
              child: Container(
                key: ValueKey(isSelected),
                width: 34.48,
                height: 34.48,
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? const Color(0xFFE53935)
                          : const Color(0xFFA9A9A9),
                  border: Border.all(
                    color:
                        isSelected
                            ? const Color(0xFFE53935)
                            : const Color(0xFFA9A9A9),
                    width: 0.82,
                  ),
                  borderRadius: BorderRadius.circular(2.46),
                ),
                child: Center(
                  child: BBText(
                    isSelected ? '$selectedWordNumber' : '00',
                    style: context.font.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.15,
                      color: context.appColors.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const Gap(12),
            BBText(
              word,
              textAlign: TextAlign.start,
              maxLines: 2,
              style: context.font.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: context.appColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
