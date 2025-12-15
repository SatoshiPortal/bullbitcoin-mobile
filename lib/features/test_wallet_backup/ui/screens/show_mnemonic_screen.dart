import 'dart:async';

import 'package:bb_mobile/core_deprecated/mixins/privacy_screen.dart';
import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/utils/constants.dart';
import 'package:bb_mobile/core_deprecated/widgets/buttons/button.dart';
import 'package:bb_mobile/core_deprecated/widgets/text/text.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/app_bar_widget.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/verify_mnemonic_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ShowMnemonicScreen extends StatefulWidget {
  const ShowMnemonicScreen({super.key});

  @override
  State<ShowMnemonicScreen> createState() => _ShowMnemonicScreenState();
}

class _ShowMnemonicScreenState extends State<ShowMnemonicScreen>
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
        return BlocBuilder<TestWalletBackupBloc, TestWalletBackupState>(
          builder: (context, state) {
            final walletName = state.selectedWallet?.isDefault ?? false
                ? context.loc.testBackupDefaultWallets
                : state.selectedWallet?.displayLabel ?? '';
            final title = context.loc.testBackupWalletTitle(walletName);

            return Scaffold(
              backgroundColor: context.appColors.onSecondary,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: AppBarWidget(title: title),
              ),
              body: Column(
                children: [
                  const Expanded(
                    child: SingleChildScrollView(child: _MnemonicDisplay()),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        BBButton.big(
                          label: context.loc.testBackupNext,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (context) => const VerifyMnemonicScreen(),
                              ),
                            );
                          },
                          bgColor: context.appColors.secondary,
                          textColor: context.appColors.onSecondary,
                        ),
                        Gap(Device.screen.height * 0.05),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MnemonicDisplay extends StatelessWidget {
  const _MnemonicDisplay();

  @override
  Widget build(BuildContext context) {
    final mnemonic = context.select(
      (TestWalletBackupBloc bloc) => bloc.state.mnemonic,
    );

    final selectedWallet =
        context.watch<TestWalletBackupBloc>().state.selectedWallet;
    final lastPhysicalBackup = selectedWallet?.latestPhysicalBackup;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          BBText(
            context.loc.testBackupWriteDownPhrase,
            textAlign: .center,
            style: context.font.headlineLarge?.copyWith(
              fontWeight: .w600,
            ),
            maxLines: 2,
          ),
          const Gap(20),
          BBText(
            context.loc.testBackupStoreItSafe,
            textAlign: .center,
            style: context.font.labelMedium?.copyWith(
              fontWeight: .w700,
              color: context.appColors.surface,
              letterSpacing: 0,
              fontSize: 12,
            ),
          ),
          if (lastPhysicalBackup != null) ...[
            BBText(
              context.loc.testBackupLastBackupTest(lastPhysicalBackup.toString().substring(0, 19)),
              textAlign: .center,
              style: context.font.labelMedium?.copyWith(
                fontWeight: .w700,
                color: context.appColors.surface,
                letterSpacing: 0,
                fontSize: 12,
              ),
            ),
          ],
          const Gap(32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (var i = 0; i < (mnemonic.length + 1) ~/ 2; i++)
                  Row(
                    children: [
                      _RecoveryPhraseWord(index: i, number: i + 1),
                      if (i + (mnemonic.length + 1) ~/ 2 < mnemonic.length)
                        _RecoveryPhraseWord(
                          index: i + (mnemonic.length + 1) ~/ 2,
                          number: i + (mnemonic.length + 1) ~/ 2 + 1,
                        )
                      else
                        const Expanded(child: SizedBox()),
                    ],
                  ),

                const _PassphraseWidget(),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: context.appColors.surface),
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
                    color: context.appColors.secondaryFixedDim,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(11),
                      topRight: Radius.circular(11),
                      bottomLeft: Radius.circular(2),
                      bottomRight: Radius.circular(2),
                    ),
                  ),
                  child: BBText(
                    context.loc.testBackupDoNotShare,
                    textAlign: .center,
                    style: context.font.headlineMedium?.copyWith(
                      fontWeight: .w500,
                      fontSize: 16,
                      color: context.appColors.secondary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: .spaceEvenly,
                    children: [
                      _buildWarningItem(
                        icon: CupertinoIcons.check_mark,
                        text: context.loc.testBackupTranscribe,
                        iconColor: const Color(0xFF34C759),
                        context: context,
                      ),
                      _buildWarningItem(
                        icon: CupertinoIcons.xmark,
                        text: context.loc.testBackupDigitalCopy,
                        iconColor: context.appColors.error,
                        context: context,
                      ),
                      _buildWarningItem(
                        icon: CupertinoIcons.xmark,
                        text: context.loc.testBackupScreenshot,
                        iconColor: context.appColors.error,
                        context: context,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
            fontWeight: .w700,
            fontSize: 12,
            color: context.appColors.secondary,
          ),
        ),
      ],
    );
  }
}

class _RecoveryPhraseWord extends StatelessWidget {
  const _RecoveryPhraseWord({required this.index, required this.number});

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
          mainAxisSize: .min,
          children: [
            Expanded(
              flex: 2,
              child: Container(
                width: 34.48,
                height: 34.48,
                decoration: BoxDecoration(
                  color: context.appColors.secondary,
                  border: Border.all(
                    color: context.appColors.secondary,
                    width: 0.82,
                  ),
                  borderRadius: BorderRadius.circular(2.46),
                ),
                child: Center(
                  child: BBText(
                    number < 10 ? '0$number' : '$number',
                    style: context.font.titleMedium?.copyWith(
                      fontWeight: .w700,
                      fontSize: 16,
                      letterSpacing: 0.15,
                      color: context.appColors.onPrimary,
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
                textAlign: .start,
                maxLines: 2,
                style: context.font.bodyLarge?.copyWith(
                  fontWeight: .w700,
                  fontSize: 14,
                  color: context.appColors.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassphraseWidget extends StatelessWidget {
  const _PassphraseWidget();

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
      child: Row(
        crossAxisAlignment: .start,
        children: [
          BBText(
            context.loc.testBackupPassphrase,
            style: context.font.labelMedium?.copyWith(
              fontWeight: .w700,
              color: context.appColors.surface,
              letterSpacing: 0,
              fontSize: 14,
            ),
          ),
          const Gap(8),
          BBText(
            passphrase,
            style: context.font.bodyLarge?.copyWith(
              fontWeight: .w700,
              fontSize: 14,
              color: context.appColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
