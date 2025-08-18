import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/test_wallet_backup_router.dart';
import 'package:bb_mobile/locator.dart';
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
        return BlocProvider(
          create:
              (context) =>
                  locator<TestWalletBackupBloc>()..add(const LoadWallets()),
          child: BlocConsumer<TestWalletBackupBloc, TestWalletBackupState>(
            listener: (context, state) {
              if (state.status == TestWalletBackupStatus.error) {
              } else if (state.status == TestWalletBackupStatus.success &&
                  state.testMnemonicOrder.isNotEmpty) {
                context.goNamed(
                  TestWalletBackupSubroute.backupTestSuccess.name,
                );
              }
            },
            builder: (context, state) {
              final isVerifying =
                  state.status == TestWalletBackupStatus.verifying;

              final mnemonicWallets =
                  state.wallets
                      .where((w) => w.signer == SignerEntity.local)
                      .toList();

              final title =
                  'Test ${state.selectedWallet?.isDefault ?? false ? 'Default Wallets' : state.selectedWallet?.displayLabel ?? ''}';

              return Scaffold(
                backgroundColor: context.colour.onSecondary,
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  flexibleSpace: TopBar(
                    color: context.colour.onSecondary,
                    onBack: () => context.pop(),
                    title: title,
                    actionIcon:
                        mnemonicWallets.length > 1
                            ? CupertinoIcons.chevron_down
                            : null,
                    onAction:
                        mnemonicWallets.length > 1
                            ? () async {
                              final bloc = context.read<TestWalletBackupBloc>();
                              final selectedId = state.selectedWallet?.id;
                              final selectedIndex = mnemonicWallets.indexWhere(
                                (w) => w.id == selectedId,
                              );

                              final selectedWalletId = await _showWalletPicker(
                                context: context,
                                wallets: mnemonicWallets,
                                initialIndex: selectedIndex,
                              );

                              if (selectedWalletId != null && mounted) {
                                bloc.add(
                                  LoadMnemonicForWallet(
                                    wallet: state.selectedWallet!,
                                  ),
                                );
                              }
                            }
                            : null,
                  ),
                ),

                body: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      FadingLinearProgress(
                        height: 3,
                        trigger: state.status == TestWalletBackupStatus.loading,
                        backgroundColor: context.colour.surface,
                        foregroundColor: context.colour.primary,
                      ),
                      Expanded(
                        child: AnimatedOpacity(
                          opacity:
                              state.status == TestWalletBackupStatus.success ||
                                      state.status ==
                                          TestWalletBackupStatus.verifying
                                  ? 1.0
                                  : 0.0,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOut,
                          child:
                              !isVerifying
                                  ? (state.shuffledMnemonic.isNotEmpty
                                      ? const TestPhysicalBackupScreen()
                                      : const SizedBox.shrink())
                                  : const ShuffledMnemonicScreen(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<String?> _showWalletPicker({
    required BuildContext context,
    required List<Wallet> wallets,
    required int initialIndex,
  }) {
    final controller = FixedExtentScrollController(
      initialItem: initialIndex >= 0 ? initialIndex : 0,
    );

    return BlurredBottomSheet.show<String>(
      context: context,
      isDismissible: true,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.4,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: context.colour.onPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
            const Gap(8),
            Expanded(
              child: CupertinoPicker(
                scrollController: controller,
                itemExtent: 70,
                onSelectedItemChanged: (_) {},
                children: [
                  for (final wallet in wallets)
                    Center(
                      child: BBText(
                        wallet.isDefault
                            ? 'Default Wallets'
                            : wallet.displayLabel,
                        style: context.font.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Gap(16),
            BBButton.big(
              label: "Confirm",
              onPressed: () {
                final wallet = wallets[controller.selectedItem];
                context.pop(wallet.id);
              },
              bgColor: context.colour.secondary,
              textColor: context.colour.onSecondary,
            ),
            const Gap(16),
          ],
        ),
      ),
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
      child: SingleChildScrollView(
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
              Padding(
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
                    const PassphraseWidget(),
                  ],
                ),
              ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shuffledMnemonic.length == 12) ...[
          for (var i = 0; i < 6; i++)
            Row(
              children: [
                ShuffledWordItem(index: i),
                ShuffledWordItem(index: i + 6),
              ],
            ),
        ],
      ],
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

        return Expanded(
          child: VerificationWordItem(
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
          ),
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

            const Gap(12),
            BBText(
              word,
              textAlign: TextAlign.start,
              maxLines: 2,
              style: context.font.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: context.colour.secondary,
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

class PassphraseWidget extends StatelessWidget {
  const PassphraseWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final passphrase = context.select(
      (TestWalletBackupBloc bloc) => bloc.state.passphrase,
    );

    if (passphrase.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2.76),
        border: Border.all(color: context.colour.surface, width: 0.69),
        boxShadow: [
          BoxShadow(color: context.colour.surface, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            'Passphrase',
            style: context.font.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colour.surface,
              letterSpacing: 0,
              fontSize: 14,
            ),
          ),
          const Gap(8),
          BBText(
            passphrase,
            style: context.font.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: context.colour.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
