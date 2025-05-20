import 'dart:async';

import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/test_wallet_backup_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class TestPhysicalBackupFlow extends StatefulWidget {
  const TestPhysicalBackupFlow();

  @override
  State<TestPhysicalBackupFlow> createState() => _TestPhysicalBackupFlowState();
}

class _TestPhysicalBackupFlowState extends State<TestPhysicalBackupFlow>
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
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(
              value:
                  locator<TestWalletBackupBloc>()
                    ..add(const LoadSeedForVerification()),
            ),
          ],
          child: BlocListener<TestWalletBackupBloc, TestWalletBackupState>(
            listener: (context, state) {
              if (state.status == TestWalletBackupStatus.error) {
              } else if (state.status == TestWalletBackupStatus.success &&
                  state.testMnemonicOrder.isNotEmpty) {
                context.goNamed(
                  TestWalletBackupSubroute.backupTestSuccess.name,
                );
              }
            },
            child: Builder(
              builder: (context) {
                final isVerifying = context.select(
                  (TestWalletBackupBloc bloc) =>
                      bloc.state.status == TestWalletBackupStatus.verifying,
                );

                return Scaffold(
                  backgroundColor: context.colour.onSecondary,
                  appBar: AppBar(
                    forceMaterialTransparency: true,
                    automaticallyImplyLeading: false,
                    flexibleSpace: TopBar(
                      onBack: () => context.pop(),
                      title: 'Test Backup',
                    ),
                  ),
                  body: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child:
                        !isVerifying
                            ? const TestPhysicalBackupScreen()
                            : const ShuffledMnemonicScreen(),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class TestPhysicalBackupScreen extends StatelessWidget {
  const TestPhysicalBackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mnemonic = context.select(
      (TestWalletBackupBloc bloc) => bloc.state.mnemonic,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(20),
            BBText(
              'Write down your recovery phrase\nin the correct order',
              textAlign: TextAlign.center,
              style: context.font.headlineLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
            ),
            const Gap(20),
            BBText(
              'Store it somewhere safe.',
              textAlign: TextAlign.center,
              style: context.font.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colour.surface,
                letterSpacing: 0,
                fontSize: 12,
              ),
            ),
            const Gap(32),
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (mnemonic.length == 12) ...[
                    for (var i = 0; i < 6; i++)
                      Row(
                        children: [
                          RecoveryPhraseWord(index: i, number: i + 1),
                          RecoveryPhraseWord(index: i + 6, number: i + 7),
                        ],
                      ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: context.colour.surface),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                  bottomLeft: Radius.circular(2),
                  bottomRight: Radius.circular(2),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: context.colour.secondaryFixedDim,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(11),
                        topRight: Radius.circular(11),
                        bottomLeft: Radius.circular(2),
                        bottomRight: Radius.circular(2),
                      ),
                    ),
                    child: BBText(
                      'DO NOT SHARE WITH ANYONE',
                      textAlign: TextAlign.center,
                      style: context.font.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: context.colour.secondary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildWarningItem(
                          icon: CupertinoIcons.check_mark,
                          text: 'Transcribe',
                          iconColor: const Color(0xFF34C759),
                          context: context,
                        ),
                        _buildWarningItem(
                          icon: CupertinoIcons.xmark,
                          text: 'Digital copy',
                          iconColor: context.colour.error,
                          context: context,
                        ),
                        _buildWarningItem(
                          icon: CupertinoIcons.xmark,
                          text: 'Screenshot',
                          iconColor: context.colour.error,
                          context: context,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Gap(16),
            BBButton.big(
              label: "Next",
              onPressed: () {
                context.read<TestWalletBackupBloc>().add(
                  const StartPhysicalBackupVerification(),
                );
              },
              bgColor: context.colour.secondary,
              textColor: context.colour.onSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningItem({
    required IconData icon,
    required String text,
    required Color iconColor,
    required BuildContext context,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const Gap(4),
        Text(
          text,
          style: context.font.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: context.colour.secondary,
          ),
        ),
      ],
    );
  }
}

class ShuffledMnemonicScreen extends StatelessWidget {
  const ShuffledMnemonicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(20),
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
            Builder(
              builder: (context) {
                final testMnemonicOrder = context.select(
                  (TestWalletBackupBloc bloc) => bloc.state.testMnemonicOrder,
                );
                final nextWordNumber =
                    testMnemonicOrder.isEmpty
                        ? 1
                        : testMnemonicOrder.length + 1;
                final showPrompt = testMnemonicOrder.length < 12;

                if (showPrompt) {
                  return Column(
                    children: [
                      BBText(
                        'What is word number $nextWordNumber?',
                        textAlign: TextAlign.center,
                        style: context.font.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.colour.outline,
                          letterSpacing: 0,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                } else {
                  return BBText(
                    'You have selected all words',
                    textAlign: TextAlign.center,
                    style: context.font.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.colour.surface,
                      letterSpacing: 0,
                      fontSize: 14,
                    ),
                  );
                }
              },
            ),
            const Gap(40),
            const Expanded(child: ShuffledMnemonicGrid()),
            const Gap(16),
            const VerifyButton(),
            const Gap(16),
          ],
        ),
      ),
    );
  }
}

class ShuffledMnemonicGrid extends StatelessWidget {
  const ShuffledMnemonicGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final shuffledMnemonic = context.select(
      (TestWalletBackupBloc bloc) => bloc.state.shuffledMnemonic,
    );

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: shuffledMnemonic.length,
      itemBuilder: (context, index) => ShuffledWordItem(index: index),
    );
  }
}

class ShuffledWordItem extends StatelessWidget {
  const ShuffledWordItem({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final (word, isSelected, actualIdx) = context.select(
          (TestWalletBackupBloc bloc) => bloc.state.shuffleElementAt(index),
        );

        return VerificationWordItem(
          word: word,
          isSelected: isSelected,
          actualIdx: actualIdx,
          onTap:
              isSelected
                  ? null
                  : () {
                    context.read<TestWalletBackupBloc>().add(
                      OnWordsSelected(shuffledIdx: index),
                    );
                  },
        );
      },
    );
  }
}

class VerifyButton extends StatelessWidget {
  const VerifyButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TestWalletBackupBloc, TestWalletBackupState>(
      builder: (context, state) {
        final bool allWordsSelected =
            state.testMnemonicOrder.length == state.mnemonic.length;

        return BBButton.big(
          label: "Verify",
          onPressed:
              allWordsSelected
                  ? () {
                    context.read<TestWalletBackupBloc>().add(
                      const VerifyPhysicalBackup(),
                    );
                  }
                  : () {},
          bgColor:
              allWordsSelected
                  ? context.colour.secondary
                  : context.colour.surface,
          textColor: context.colour.onSecondary,
        );
      },
    );
  }
}

class VerificationWordItem extends StatelessWidget {
  const VerificationWordItem({
    super.key,
    required this.word,
    required this.isSelected,
    required this.actualIdx,
    this.onTap,
  });

  final String word;
  final bool isSelected;
  final int actualIdx;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 20),
        // padding: EdgeInsets.only(left: padLeft, right: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2.76),
          border: Border.all(color: context.colour.surface, width: 0.69),
          boxShadow: [
            BoxShadow(
              color: context.colour.surface,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        height: 41,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              flex: 2,
              child: AnimatedSwitcher(
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
                      isSelected ? '${actualIdx + 1}' : '00',
                      style: context.font.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Gap(12),
            Expanded(
              flex: 6,
              child: BBText(
                word,
                textAlign: TextAlign.start,
                maxLines: 2,
                style: context.font.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: context.colour.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecoveryPhraseWord extends StatelessWidget {
  const RecoveryPhraseWord({
    super.key,
    required this.index,
    required this.number,
  });

  final int index;
  final int number;

  @override
  Widget build(BuildContext context) {
    final mnemonic = context.select(
      (TestWalletBackupBloc bloc) => bloc.state.mnemonic,
    );

    final word = index < mnemonic.length ? mnemonic[index] : '';

    return Expanded(
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 20),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2.76),
          border: Border.all(color: context.colour.surface, width: 0.69),
          boxShadow: [
            BoxShadow(
              color: context.colour.surface,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        height: 41,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              flex: 2,
              child: Container(
                width: 34.48,
                height: 34.48,
                decoration: BoxDecoration(
                  color: context.colour.secondary,
                  border: Border.all(
                    color: context.colour.secondary,
                    width: 0.82,
                  ),
                  borderRadius: BorderRadius.circular(2.46),
                ),
                child: Center(
                  child: BBText(
                    number < 10 ? '0$number' : '$number',
                    style: context.font.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.15,
                      color: context.colour.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const Gap(12),
            Expanded(
              flex: 6,
              child: BBText(
                word,
                textAlign: TextAlign.start,
                maxLines: 2,
                style: context.font.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: context.colour.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
