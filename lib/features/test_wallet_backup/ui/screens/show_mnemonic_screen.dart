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

class ShowMnemonicScreen extends StatefulWidget {
  final List<String>? _mnemonic;
  final String? _title;
  final String? _notice;
  final VoidCallback? _onContinue;

  const ShowMnemonicScreen({super.key})
    : _mnemonic = null,
      _title = null,
      _notice = null,
      _onContinue = null;

  const ShowMnemonicScreen.forMnemonic({
    super.key,
    required List<String> this._mnemonic,
    required String this._title,
    required VoidCallback this._onContinue,
    this._notice,
  });

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
        if (snapshot.connectionState != ConnectionState.done ||
            snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: snapshot.hasError
                  ? Text(context.loc.oopsSomethingWentWrong)
                  : const CircularProgressIndicator(),
            ),
          );
        }
        if (widget._mnemonic != null) {
          return _buildScreen(
            AppBar(title: Text(widget._title!)),
            _MnemonicDisplay(
              mnemonic: widget._mnemonic,
              notice: widget._notice,
            ),
          );
        }
        return BlocBuilder<TestWalletBackupBloc, TestWalletBackupState>(
          builder: (context, state) {
            final walletName = state.selectedWallet?.isDefault ?? false
                ? context.loc.testBackupDefaultWallets
                : state.selectedWallet?.displayLabel(context) ?? '';
            final title = context.loc.testBackupWalletTitle(walletName);

            return _buildScreen(
              PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: AppBarWidget(title: title),
              ),
              const _MnemonicDisplay(),
            );
          },
        );
      },
    );
  }

  Widget _buildScreen(PreferredSizeWidget appBar, Widget display) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: appBar,
      body: Column(
        children: [
          Expanded(child: SingleChildScrollView(child: display)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                BBButton.big(
                  label: context.loc.testBackupNext,
                  onPressed:
                      widget._onContinue ??
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const VerifyMnemonicScreen(),
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
  }
}

/// Keeps mnemonic rendering in ephemeral widget state, outside bloc state and logs.
class _MnemonicDisplay extends StatefulWidget {
  final List<String>? mnemonic;
  final String? notice;

  const _MnemonicDisplay({this.mnemonic, this.notice});

  @override
  State<_MnemonicDisplay> createState() => _MnemonicDisplayState();
}

class _MnemonicDisplayState extends State<_MnemonicDisplay> {
  String? _fingerprint;
  Future<(List<String>, String?)>? _secretFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.mnemonic != null) {
      _secretFuture ??= Future.value((widget.mnemonic!, null));
      return;
    }
    final fingerprint = context
        .read<TestWalletBackupBloc>()
        .state
        .selectedWallet
        ?.masterFingerprint;
    if (fingerprint != _fingerprint) {
      _fingerprint = fingerprint;
      _secretFuture = fingerprint == null
          ? null
          : context.read<TestWalletBackupBloc>().loadSelectedWalletMnemonic();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedWallet = widget.mnemonic == null
        ? context.watch<TestWalletBackupBloc>().state.selectedWallet
        : null;
    final lastPhysicalBackup = selectedWallet?.latestPhysicalBackup;

    return FutureBuilder<(List<String>, String?)>(
      future: _secretFuture,
      builder: (context, snapshot) {
        final mnemonic = snapshot.data?.$1 ?? const <String>[];
        final passphrase = snapshot.data?.$2 ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              if (widget.notice != null) ...[
                BBText(
                  widget.notice!,
                  style: context.font.bodyMedium,
                  textAlign: .center,
                ),
                const Gap(20),
              ],
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
              if (lastPhysicalBackup != null) ...[
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
              ],
              const Gap(32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ExcludeSemantics(
                  child: Column(
                    children: [
                      if (snapshot.hasError)
                        BBText(
                          context.loc.oopsSomethingWentWrong,
                          textAlign: .center,
                          style: context.font.bodyLarge?.copyWith(
                            color: context.appColors.error,
                          ),
                        )
                      else if (!snapshot.hasData)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        for (var i = 0; i < (mnemonic.length + 1) ~/ 2; i++)
                          Row(
                            children: [
                              _RecoveryPhraseWord(
                                number: i + 1,
                                word: mnemonic[i],
                              ),
                              if (i + (mnemonic.length + 1) ~/ 2 <
                                  mnemonic.length)
                                _RecoveryPhraseWord(
                                  number: i + (mnemonic.length + 1) ~/ 2 + 1,
                                  word:
                                      mnemonic[i + (mnemonic.length + 1) ~/ 2],
                                )
                              else
                                const Expanded(child: SizedBox()),
                            ],
                          ),
                        _PassphraseWidget(passphrase: passphrase),
                      ],
                    ],
                  ),
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
                          _buildWarningItem(
                            icon: CupertinoIcons.check_mark,
                            text: context.loc.testBackupTranscribe,
                            iconColor: context.appColors.success,
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
      },
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
  const _RecoveryPhraseWord({required this.number, required this.word});

  final int number;
  final String word;

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
  const _PassphraseWidget({required this.passphrase});

  final String passphrase;

  @override
  Widget build(BuildContext context) {
    if (passphrase.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Row(
        crossAxisAlignment: .start,
        children: [
          BBText(
            context.loc.testBackupPassphrase,
            style: context.font.labelMedium?.copyWith(
              fontWeight: .w700,
              color: context.appColors.onSurface,
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
