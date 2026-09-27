import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/test_wallet_backup_failure_l10n.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/app_bar_widget.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/backup_test_success.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_privacy/screen_privacy.dart';
import 'package:secrets/secrets.dart'
    show MnemonicTile, Secret, SecretExtension;

class VerifyMnemonicScreen extends StatefulWidget {
  const VerifyMnemonicScreen({super.key});

  @override
  State<VerifyMnemonicScreen> createState() => _VerifyMnemonicScreenState();
}

class _VerifyMnemonicScreenState extends State<VerifyMnemonicScreen>
    with PrivacyScreen {
  String? _fingerprint;
  Future<Result<Secret, TestWalletBackupFailure>>? _secret;

  /// Set when no wallet could be selected at all (e.g. `LoadWallets`
  /// failed): no load is coming, so the challenge shows this instead of a
  /// spinner that never ends.
  TestWalletBackupFailure? _unavailable;

  /// How far along the user is. A count, not the words — the phrase and the
  /// order the user is building both live inside `MnemonicChallenge`, which
  /// is why this screen no longer has a `_mnemonic` field.
  int _placed = 0;
  int _total = 0;

  late final Future<void> _privacyFuture = enableScreenPrivacy();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSecret(
      context
          .read<TestWalletBackupBloc>()
          .state
          .selectedWallet
          ?.masterFingerprint,
    );
  }

  /// Loads the secret whenever the selected wallet changes. The test flow
  /// opens this screen before the wallets have loaded, so the fingerprint
  /// read at mount can still be null; the bloc listener calls this again
  /// once a wallet is selected. Progress restarts with the new wallet.
  /// Returns whether anything changed; the caller decides whether to rebuild.
  bool _syncSecret(String? fingerprint) {
    if (fingerprint == null || fingerprint == _fingerprint) return false;
    _fingerprint = fingerprint;
    _unavailable = null;
    _placed = 0;
    _total = 0;
    _secret = context.read<TestWalletBackupBloc>().loadSelectedWalletSecret();
    return true;
  }

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
        // Nothing draws before the OS flag call has returned: a builder that
        // ignores `connectionState` runs during `waiting` (Codex, 2026-09-17).
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        return BlocConsumer<TestWalletBackupBloc, TestWalletBackupState>(
          listenWhen: (previous, current) =>
              previous.selectedWallet?.masterFingerprint !=
                  current.selectedWallet?.masterFingerprint ||
              previous.verificationStatus != current.verificationStatus ||
              previous.failure != current.failure,
          listener: (context, state) {
            if (_syncSecret(state.selectedWallet?.masterFingerprint)) {
              setState(() {});
            }
            if (state.failure case final failure?) {
              // With no wallet selected, no load is coming that would end the
              // spinner (e.g. LoadWallets itself failed), so end it here.
              if (state.selectedWallet == null) {
                setState(() => _unavailable = failure);
              }
              SnackBarUtils.showSnackBar(
                context,
                failure.toTranslated(context),
              );
              context.read<TestWalletBackupBloc>().add(const ClearFailure());
              return;
            }
            switch (state.verificationStatus) {
              case BackupVerificationStatus.success:
                context.read<TestWalletBackupBloc>().add(const ClearFailure());
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const BackupTestSuccessScreen(),
                  ),
                );
              case BackupVerificationStatus.failure:
              case BackupVerificationStatus.idle:
                break;
            }
          },
          builder: (context, state) {
            final walletName = state.selectedWallet?.isDefault ?? false
                ? context.loc.testBackupDefaultWallets
                : state.selectedWallet?.displayLabel(context) ?? '';
            final title = context.loc.testBackupWalletTitle(walletName);
            final showPrompt = _total == 0 || _placed < _total;

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
                    crossAxisAlignment: .stretch,
                    children: [
                      BBText(
                        context.loc.testBackupTapWordsInOrder,
                        textAlign: .center,
                        maxLines: 2,
                        style: context.font.headlineLarge?.copyWith(
                          fontWeight: .w600,
                          fontSize: 16,
                          letterSpacing: 0,
                        ),
                      ),
                      const Gap(20),
                      if (showPrompt)
                        BBText(
                          context.loc.testBackupWhatIsWordNumber(_placed + 1),
                          textAlign: .center,
                          style: context.font.labelMedium?.copyWith(
                            fontWeight: .w700,
                            color: context.appColors.outline,
                            letterSpacing: 0,
                            fontSize: 12,
                          ),
                        )
                      else
                        BBText(
                          context.loc.testBackupAllWordsSelected,
                          textAlign: .center,
                          style: context.font.labelMedium?.copyWith(
                            fontWeight: .w700,
                            color: context.appColors.surface,
                            letterSpacing: 0,
                            fontSize: 14,
                          ),
                        ),
                      const Gap(16),
                      _Challenge(
                        // Keyed by wallet: a FutureBuilder handed a new future
                        // keeps the previous snapshot's data until it resolves,
                        // which would draw the previous wallet's words under
                        // the newly selected one.
                        key: ValueKey<String?>(_fingerprint),
                        secret: _secret,
                        unavailable: _unavailable,
                        onProgress: (placed, total) {
                          if (!mounted) return;
                          setState(() {
                            _placed = placed;
                            _total = total;
                          });
                        },
                      ),
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

/// The sealed challenge. The words, their shuffle and the running comparison
/// all live inside `MnemonicChallenge`; this only styles a tile and reports
/// the outcome.
class _Challenge extends StatelessWidget {
  const _Challenge({
    super.key,
    required this.secret,
    required this.unavailable,
    required this.onProgress,
  });

  final Future<Result<Secret, TestWalletBackupFailure>>? secret;
  final TestWalletBackupFailure? unavailable;
  final void Function(int placed, int total) onProgress;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Result<Secret, TestWalletBackupFailure>>(
      future: secret,
      builder: (context, snapshot) {
        // The future no longer throws — a failure comes back as an Err — but
        // snapshot.hasError is still honoured so an unexpected throw degrades
        // to the generic message instead of a spinner.
        // No wallet could be selected: the snackbar already said why, and no
        // load is coming, so the spinner ends here.
        if (secret == null && unavailable != null) {
          return const SizedBox.shrink();
        }
        final failure = switch (snapshot.data) {
          Err(:final failure) => failure,
          _ when snapshot.hasError => const TestWalletBackupUnexpectedFailure(),
          _ => null,
        };
        if (failure != null) {
          return BBText(
            failure.toTranslated(context),
            textAlign: .center,
            style: context.font.bodyLarge?.copyWith(
              color: context.appColors.error,
            ),
          );
        }
        final value = switch (snapshot.data) {
          Ok(:final value) => value,
          _ => null,
        };
        if (value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return value.widgets.mnemonicChallenge(
          style: context.font.bodyLarge?.copyWith(
            fontWeight: .w700,
            fontSize: 14,
            color: context.appColors.secondary,
          ),
          placeholder: const Center(child: CircularProgressIndicator()),
          failureBuilder: (context, failure, retry) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BBText(
                context.loc.oopsSomethingWentWrong,
                textAlign: .center,
                style: context.font.bodyLarge?.copyWith(
                  color: context.appColors.error,
                ),
              ),
              const Gap(16),
              BullButton.small(
                label: context.loc.retry,
                onPressed: retry,
                bgColor: context.appColors.secondary,
                textColor: context.appColors.onSecondary,
              ),
            ],
          ),
          onProgress: onProgress,
          onSolved: () => context.read<TestWalletBackupBloc>().add(
            const VerifyPhysicalBackup(),
          ),
          onMistake: () => SnackBarUtils.showSnackBar(
            context,
            context.loc.testBackupErrorIncorrectOrder,
          ),
          tileBuilder: (context, tile) => Expanded(child: _Tile(tile: tile)),
          layoutBuilder: (context, tiles) => Column(
            children: [
              for (var i = 0; i < (tiles.length + 1) ~/ 2; i++)
                Row(
                  children: [
                    tiles[i],
                    if (i + (tiles.length + 1) ~/ 2 < tiles.length)
                      tiles[i + (tiles.length + 1) ~/ 2]
                    else
                      const Expanded(child: SizedBox()),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tile});

  final MnemonicTile tile;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: tile.onTap,
      splashColor: context.appColors.transparent,
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Container(
                key: ValueKey(tile.isPlaced),
                width: 34.48,
                height: 34.48,
                decoration: BoxDecoration(
                  color: tile.isPlaced
                      ? context.appColors.primary
                      : context.appColors.textMuted,
                  border: Border.all(
                    color: tile.isPlaced
                        ? context.appColors.primary
                        : context.appColors.textMuted,
                    width: 0.82,
                  ),
                  borderRadius: BorderRadius.circular(2.46),
                ),
                child: Center(
                  child: BBText(
                    tile.position?.toString() ?? '00',
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
            // The word as the package hands it: a widget, no accessor.
            tile.word,
          ],
        ),
      ),
    );
  }
}
