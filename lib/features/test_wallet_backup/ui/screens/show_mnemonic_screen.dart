import 'dart:async';

import 'package:screen_privacy/screen_privacy.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/test_wallet_backup_failure_l10n.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/app_bar_widget.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/verify_mnemonic_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullScreenPrivacyGate, BullShapesX, BullText, Gap;
import 'package:secrets/secrets.dart' show Secret, SecretExtension;

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
  late Future<bool> _privacyFuture = enableScreenPrivacy();

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
  Future<Result<Secret, TestWalletBackupFailure>>? _secret;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.mnemonic != null) {
      _secretFuture ??= Future.value(Ok((widget.mnemonic!, null)));
      return;
    }
    final fingerprint = context
        .read<TestWalletBackupBloc>()
        .state
        .selectedWallet
        ?.singleLocalSeedFingerprint;
    if (fingerprint != _fingerprint) {
      _fingerprint = fingerprint;
      _secret = fingerprint == null
          ? null
          : context.read<TestWalletBackupBloc>().loadSelectedWalletSecret();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedWallet = widget.mnemonic == null
        ? context.watch<TestWalletBackupBloc>().state.selectedWallet
        : null;
    final lastPhysicalBackup = selectedWallet?.latestPhysicalBackup;

    return FutureBuilder<
      Result<(List<String>, String?), TestWalletBackupFailure>
    >(
      future: _secretFuture,
      builder: (context, snapshot) {
        final result = snapshot.data;
        final (mnemonic, passphrase) = switch (result) {
          Ok(:final value) => (value.$1, value.$2 ?? ''),
          _ => (const <String>[], ''),
        };
        // The future no longer throws — a failure comes back as an Err — but
        // snapshot.hasError is still honoured so an unexpected throw degrades
        // to the generic message instead of an empty phrase list.
        final failure = switch (result) {
          Err(:final failure) => failure,
          _ =>
            snapshot.hasError
                ? const TestWalletBackupUnexpectedFailure()
                : null,
        };

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
            // Keyed by wallet: a FutureBuilder handed a new future keeps the
            // previous snapshot's data until it resolves, which would draw the
            // previous wallet's words under the newly selected one.
            child: FutureBuilder<Result<Secret, TestWalletBackupFailure>>(
              key: ValueKey<String?>(_fingerprint),
              future: _secret,
              builder: (context, snapshot) {
                // The future no longer throws — a failure comes back as an
                // Err — but snapshot.hasError is still honoured so an
                // unexpected throw degrades to the generic message.
                switch (snapshot.data) {
                  case Err(:final failure):
                    return _DisplayError(failure: failure);
                  case _ when snapshot.hasError:
                    return const _DisplayError();
                  default:
                    break;
                }
                final secret = switch (snapshot.data) {
                  Ok(:final value) => value,
                  _ => null,
                };
                if (secret == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return secret.widgets.mnemonicView(
                  placeholder: const Center(child: CircularProgressIndicator()),
                  failureBuilder: (context, failure, retry) =>
                      _DisplayError(onRetry: retry),
                  passphraseLabel: context.loc.testBackupPassphrase,
                  passphraseLabelStyle: context.font.labelMedium?.copyWith(
                    fontWeight: .w700,
                    color: context.appColors.onSurface,
                    letterSpacing: 0,
                    fontSize: 14,
                  ),
                ),
              ],
              const Gap(32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ExcludeSemantics(
                  child: Column(
                    children: [
                      if (failure != null)
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
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: context.appColors.secondaryFixedDim,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(context.bullShapes.card),
                      topRight: Radius.circular(context.bullShapes.card),
                      bottomLeft: Radius.circular(context.bullShapes.card),
                      bottomRight: Radius.circular(context.bullShapes.card),
                    ),
                  ),
                  child: BullText(
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
  final TestWalletBackupFailure? failure;
  final VoidCallback? onRetry;

  const _DisplayError({this.failure, this.onRetry});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      BullText(
        failure?.toTranslated(context) ?? context.loc.oopsSomethingWentWrong,
        textAlign: .center,
        style: context.font.bodyLarge?.copyWith(color: context.appColors.error),
      ),
      if (onRetry case final retry?) ...[
        const Gap(16),
        BullButton.small(
          label: context.loc.retry,
          onPressed: retry,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
      ],
    ],
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
          borderRadius: BorderRadius.circular(context.bullShapes.card),
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
                  borderRadius: BorderRadius.circular(context.bullShapes.badge),
                ),
                child: Center(
                  child: BullText(
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
