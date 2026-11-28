import 'dart:async';

import 'package:screen_privacy/screen_privacy.dart';
import 'package:backups/src/backups_l10n.dart';
import 'package:primitives/primitives.dart';
import 'package:backups/src/domain/test_wallet_backup_failure.dart';
import 'package:backups/src/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:backups/src/presentation/test_wallet_backup_failure_l10n.dart';
import 'package:backups/src/ui/app_bar_widget.dart';
import 'package:backups/src/ui/screens/verify_mnemonic_screen.dart';
import 'package:access/access.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullThemeX,
        BullButtonSize,
        BullButton,
        BullFadingLinearProgress,
        BullScreenPrivacyGate,
        BullShapesX,
        BullText,
        BullTypographyX,
        Gap;
import 'package:secrets/secrets.dart' show Secret, SecretExtension;

class ShowMnemonicScreen extends StatefulWidget {
  final Access access;
  final void Function(BuildContext) onTestSucceeded;
  final ImageProvider successImage;
  const ShowMnemonicScreen({
    super.key,
    required this.onTestSucceeded,
    required this.successImage,
    this.access = const Access(),
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
    // Nothing draws before capture blocking is confirmed: the gate waits for
    // the OS flag and hides the words if the platform refused it.
    return BullScreenPrivacyGate(
      unavailableMessage: context.loc.screenPrivacyUnavailable,
      retryLabel: context.loc.retry,
      protection: _privacyFuture,
      onRetry: () => setState(() {
        _privacyFuture = enableScreenPrivacy();
      }),
      builder: (context) {
        return BlocBuilder<TestWalletBackupBloc, TestWalletBackupState>(
          builder: (context, state) {
            final wallet = state.selectedWallet;
            final walletName = wallet == null
                ? context.loc.walletDetailsUnnamedWalletFallback
                : context.backupWalletName(wallet);
            final title = context.loc.testBackupWalletTitle(walletName);

            return Scaffold(
              backgroundColor: context.bull.background,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: AppBarWidget(title: title),
              ),
              body: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: _MnemonicDisplay(
                        key: ValueKey(state.selectedWallet?.id),
                        access: widget.access,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        BullButton.primary(
                          label: context.loc.testBackupNext,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => VerifyMnemonicScreen(
                                  onTestSucceeded: widget.onTestSucceeded,
                                  successImage: widget.successImage,
                                ),
                              ),
                            );
                          },
                        ),
                        Gap(MediaQuery.sizeOf(context).height * 0.05),
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
  final Access access;
  const _MnemonicDisplay({super.key, required this.access});

  @override
  State<_MnemonicDisplay> createState() => _MnemonicDisplayState();
}

class _MnemonicDisplayState extends State<_MnemonicDisplay>
    with WidgetsBindingObserver {
  String? _fingerprint;
  bool _showPassphrase = false;
  int _revealGeneration = 0;
  Future<Result<Secret, TestWalletBackupFailure>>? _secret;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _revealGeneration++;
      if (_showPassphrase) setState(() => _showPassphrase = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final fingerprint = context
        .read<TestWalletBackupBloc>()
        .state
        .selectedWallet
        ?.fingerprint
        ?.hex;
    if (fingerprint != _fingerprint) {
      _revealGeneration++;
      _fingerprint = fingerprint;
      _showPassphrase = false;
      _secret = fingerprint == null
          ? null
          : context.read<TestWalletBackupBloc>().loadSelectedWalletSecret();
    }
  }

  Future<void> _togglePassphrase() async {
    if (_showPassphrase) {
      setState(() => _showPassphrase = false);
      return;
    }
    final generation = ++_revealGeneration;
    final fingerprint = _fingerprint;
    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (gateContext) => widget.access.buildReauthenticationGate(
          canPop: true,
          onSuccess: (_) => Navigator.of(gateContext).pop(true),
        ),
      ),
    );
    if (!mounted ||
        accepted != true ||
        generation != _revealGeneration ||
        fingerprint != _fingerprint ||
        fingerprint !=
            context
                .read<TestWalletBackupBloc>()
                .state
                .selectedWallet
                ?.fingerprint
                ?.hex) {
      return;
    }
    setState(() => _showPassphrase = true);
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
          BullText(
            context.loc.testBackupWriteDownPhrase,
            textAlign: .center,
            style: context.bullType.subtitle
                .copyWith(fontWeight: FontWeight.w700)
                .copyWith(fontWeight: .w600, color: context.bull.text),
            maxLines: 2,
          ),
          const Gap(20),
          BullText(
            context.loc.testBackupStoreItSafe,
            textAlign: .center,
            style: context.bullType.caption.copyWith(
              fontWeight: .w700,
              color: context.bull.textMuted,
              letterSpacing: 0,
            ),
          ),
          if (lastPhysicalBackup != null)
            BullText(
              context.loc.testBackupLastBackupTest(
                lastPhysicalBackup.toString().substring(0, 19),
              ),
              textAlign: .center,
              style: context.bullType.caption.copyWith(
                fontWeight: .w700,
                color: context.bull.textMuted,
                letterSpacing: 0,
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
                  return BullFadingLinearProgress(
                    trigger: true,
                    foregroundColor: context.bull.primary,
                  );
                }
                return Column(
                  children: [
                    secret.widgets.mnemonicView(
                      showPassphrase: _showPassphrase,
                      placeholder: BullFadingLinearProgress(
                        trigger: true,
                        foregroundColor: context.bull.primary,
                      ),
                      failureBuilder: (context, failure, retry) =>
                          _DisplayError(onRetry: retry),
                      passphraseLabel: context.loc.testBackupPassphrase,
                      passphraseLabelStyle: context.bullType.label.copyWith(
                        fontWeight: .w700,
                        color: context.bull.onSurface,
                        letterSpacing: 0,
                      ),
                      style: context.bullType.label.copyWith(
                        fontWeight: .w700,
                        color: context.bull.secondary,
                      ),
                      wordBuilder: (context, number, word) =>
                          _RecoveryPhraseWord(number: number, word: word),
                      // Two columns, numbered down each: the widgets come back
                      // in order and carry no word this layer can read.
                      layoutBuilder: (context, words) => Column(
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
                    ),
                    if (secret.info.hasPassphrase) ...[
                      Text(context.loc.passphraseWordsIncompleteWarning),
                      TextButton(
                        onPressed: _togglePassphrase,
                        child: Text(
                          _showPassphrase
                              ? context.loc.passphraseHide
                              : context.loc.passphraseShow,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: context.bull.border),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(context.bullShapes.card),
                topRight: Radius.circular(context.bullShapes.card),
                bottomLeft: Radius.circular(context.bullShapes.card),
                bottomRight: Radius.circular(context.bullShapes.card),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: context.bull.secondaryFixedDim,
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
                    style: context.bullType.body.copyWith(
                      fontWeight: .w500,
                      color: context.bull.secondary,
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
                        iconColor: context.bull.success,
                      ),
                      _WarningItem(
                        icon: CupertinoIcons.xmark,
                        text: context.loc.testBackupDigitalCopy,
                        iconColor: context.bull.error,
                      ),
                      _WarningItem(
                        icon: CupertinoIcons.xmark,
                        text: context.loc.testBackupScreenshot,
                        iconColor: context.bull.error,
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
        style: context.bullType.body
            .copyWith(fontWeight: FontWeight.w500)
            .copyWith(color: context.bull.error),
      ),
      if (onRetry case final retry?) ...[
        const Gap(16),
        BullButton.secondary(
          size: BullButtonSize.small,
          label: context.loc.retry,
          onPressed: retry,
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
        style: context.bullType.caption.copyWith(
          fontWeight: .w700,
          color: context.bull.secondary,
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
          color: context.bull.surface,
          borderRadius: BorderRadius.circular(context.bullShapes.card),
          border: Border.all(color: context.bull.border, width: 0.69),
          boxShadow: [
            BoxShadow(
              color: context.bull.border.withValues(alpha: 0.3),
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
                  color: context.bull.secondary,
                  border: Border.all(
                    color: context.bull.secondary,
                    width: 0.82,
                  ),
                  borderRadius: BorderRadius.circular(context.bullShapes.badge),
                ),
                child: Center(
                  child: BullText(
                    number < 10 ? '0$number' : '$number',
                    style: context.bullType.body.copyWith(
                      fontWeight: .w700,
                      letterSpacing: 0.15,
                      color: context.bull.onSecondary,
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
