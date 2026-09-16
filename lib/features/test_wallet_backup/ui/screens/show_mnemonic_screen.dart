import 'dart:async';

import 'package:screen_privacy/screen_privacy.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/app_bar_widget.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/verify_mnemonic_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:secrets/secrets.dart' show MnemonicView, Secret;

class ShowMnemonicScreen extends StatefulWidget {
  const ShowMnemonicScreen({super.key});

  @override
  State<ShowMnemonicScreen> createState() => _ShowMnemonicScreenState();
}

class _ShowMnemonicScreenState extends State<ShowMnemonicScreen>
    with PrivacyScreen {
  late final Future<void> _privacyFuture = enableScreenPrivacy();

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _privacyFuture,
      builder: (context, snapshot) {
        return BlocBuilder<TestWalletBackupBloc, TestWalletBackupState>(
          builder: (context, state) {
            final walletName = state.selectedWallet?.isDefault ?? false
                ? context.loc.testBackupDefaultWallets
                : state.selectedWallet?.displayLabel(context) ?? '';
            final title = context.loc.testBackupWalletTitle(walletName);

            return Scaffold(
              backgroundColor: context.appColors.background,
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
                                builder: (context) =>
                                    const VerifyMnemonicScreen(),
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

/// Sealed secret display: `MnemonicView` reads the mnemonic inside itself and
/// calls back only to style one word at a time. Nothing here — and nothing in
/// the bloc — ever holds the phrase.
class _MnemonicDisplay extends StatefulWidget {
  const _MnemonicDisplay();

  @override
  State<_MnemonicDisplay> createState() => _MnemonicDisplayState();
}

class _MnemonicDisplayState extends State<_MnemonicDisplay> {
  String? _fingerprint;
  Future<Secret>? _secret;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final fingerprint = context
        .read<TestWalletBackupBloc>()
        .state
        .selectedWallet
        ?.masterFingerprint;
    if (fingerprint != _fingerprint) {
      _fingerprint = fingerprint;
      _secret = fingerprint == null
          ? null
          : context.read<TestWalletBackupBloc>().loadSelectedWalletSecret();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedWallet = context
        .watch<TestWalletBackupBloc>()
        .state
        .selectedWallet;
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
              color: context.appColors.text,
            ),
            maxLines: 2,
          ),
          const Gap(20),
          BBText(
            context.loc.testBackupStoreItSafe,
            textAlign: .center,
            style: context.font.labelMedium?.copyWith(
              fontWeight: .w700,
              color: context.appColors.textMuted,
              letterSpacing: 0,
              fontSize: 12,
            ),
          ),
          if (lastPhysicalBackup != null)
            BBText(
              context.loc.testBackupLastBackupTest(
                lastPhysicalBackup.toString().substring(0, 19),
              ),
              textAlign: .center,
              style: context.font.labelMedium?.copyWith(
                fontWeight: .w700,
                color: context.appColors.textMuted,
                letterSpacing: 0,
                fontSize: 12,
              ),
            ),
          const Gap(32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FutureBuilder<Secret>(
              future: _secret,
              builder: (context, snapshot) {
                if (snapshot.hasError) return const _DisplayError();
                final secret = snapshot.data;
                if (secret == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return MnemonicView(
                  secret: secret,
                  placeholder: const Center(child: CircularProgressIndicator()),
                  onFailure: (context, failure) => const _DisplayError(),
                  passphraseLabel: context.loc.testBackupPassphrase,
                  passphraseLabelStyle: context.font.labelMedium?.copyWith(
                    fontWeight: .w700,
                    color: context.appColors.onSurface,
                    letterSpacing: 0,
                    fontSize: 14,
                  ),
                  style: context.font.bodyLarge?.copyWith(
                    fontWeight: .w700,
                    fontSize: 14,
                    color: context.appColors.secondary,
                  ),
                  wordBuilder: (context, number, word) =>
                      _RecoveryPhraseWord(number: number, word: word),
                  // Two columns, numbered down each: the widgets come back
                  // in order and carry no word this layer can read.
                  layout: (context, words) => Column(
                    children: [
                      for (var i = 0; i < (words.length + 1) ~/ 2; i++)
                        Row(
                          children: [
                            words[i],
                            if (i + (words.length + 1) ~/ 2 < words.length)
                              words[i + (words.length + 1) ~/ 2]
                            else
                              const Expanded(child: SizedBox()),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: context.appColors.border),
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
                      _WarningItem(
                        icon: CupertinoIcons.check_mark,
                        text: context.loc.testBackupTranscribe,
                        iconColor: context.appColors.success,
                      ),
                      _WarningItem(
                        icon: CupertinoIcons.xmark,
                        text: context.loc.testBackupDigitalCopy,
                        iconColor: context.appColors.error,
                      ),
                      _WarningItem(
                        icon: CupertinoIcons.xmark,
                        text: context.loc.testBackupScreenshot,
                        iconColor: context.appColors.error,
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
}

class _DisplayError extends StatelessWidget {
  const _DisplayError();

  @override
  Widget build(BuildContext context) => BBText(
    context.loc.oopsSomethingWentWrong,
    textAlign: .center,
    style: context.font.bodyLarge?.copyWith(color: context.appColors.error),
  );
}

class _WarningItem extends StatelessWidget {
  const _WarningItem({
    required this.icon,
    required this.text,
    required this.iconColor,
  });

  final IconData icon;
  final String text;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Row(
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

class _RecoveryPhraseWord extends StatelessWidget {
  const _RecoveryPhraseWord({required this.number, required this.word});

  final int number;

  /// The word as the package hands it: a widget to place, with no accessor
  /// for the text. Styled through `MnemonicView.style`.
  final Widget word;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 20),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(2.76),
          border: Border.all(color: context.appColors.border, width: 0.69),
          boxShadow: [
            BoxShadow(
              color: context.appColors.border.withValues(alpha: 0.3),
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
                      color: context.appColors.onSecondary,
                    ),
                  ),
                ),
              ),
            ),
            const Gap(12),
            Expanded(flex: 6, child: word),
          ],
        ),
      ),
    );
  }
}
