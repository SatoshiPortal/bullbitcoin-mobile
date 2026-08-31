import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/test_wallet_backup_failure_l10n.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/app_bar_widget.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/backup_test_success.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullScreenPrivacyGate,
        BullShapesX,
        BullSnackBar,
        BullText,
        Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_privacy/screen_privacy.dart';
import 'package:secrets/secrets.dart'
    show MnemonicTile, Secret, SecretExtension;

class VerifyMnemonicScreen extends StatefulWidget {
  final VoidCallback? onVerified;

  final List<String>? _providedMnemonic;
  final String? _title;

  const VerifyMnemonicScreen({super.key, this.onVerified})
    : _providedMnemonic = null,
      _title = null;

  const VerifyMnemonicScreen.forMnemonic({
    super.key,
    required List<String> mnemonic,
    required String this._title,
    required VoidCallback this.onVerified,
  }) : _providedMnemonic = mnemonic;

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

  late Future<bool> _privacyFuture = enableScreenPrivacy();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget._providedMnemonic != null) {
      if (_isLoading) {
        _mnemonic = widget._providedMnemonic!;
        _shuffled = [..._mnemonic]..shuffle();
        _isLoading = false;
      }
      return;
    }
    _syncSecret(
      context
          .read<TestWalletBackupBloc>()
          .state
          .selectedWallet
          ?.localMasterFingerprints.single,
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
    unawaited(_loadSecret(fingerprint));
  }

  Future<void> _loadSecret(String fingerprint) async {
    setState(() => _isLoading = true);
    final result = await context
        .read<TestWalletBackupBloc>()
        .loadSelectedWalletMnemonic();
    // Drop a load overtaken by a later wallet switch, so the words of the
    // previous wallet never land under the newly selected one.
    if (!mounted || fingerprint != _fingerprint) return;
    switch (result) {
      case Ok(:final value):
        final (mnemonic, _) = value;
        setState(() {
          _mnemonic = mnemonic;
          _shuffled = [...mnemonic]..shuffle();
          _selectedIndices = [];
          _isLoading = false;
        });
      case Err(:final failure):
        // Surfaced instead of silently dropped: the previous catch left the
        // screen on an empty word list with no explanation. The words of the
        // previously selected wallet are cleared too, so they never show
        // under the name of the wallet whose read failed.
        setState(() {
          _mnemonic = [];
          _shuffled = [];
          _selectedIndices = [];
          _isLoading = false;
        });
        SnackBarUtils.showSnackBar(context, failure.toTranslated(context));
    }
  }

  void _resetGame() {
    setState(() {
      _shuffled = [..._mnemonic]..shuffle();
      _selectedIndices = [];
    });
  }

  void _onWordTap(int index) {
    final word = _shuffled[index];
    final candidate = [for (final i in _selectedIndices) _shuffled[i], word];

    final isCorrectSoFar = List.generate(
      candidate.length,
      (i) => candidate[i] == _mnemonic[i],
    ).every((e) => e);

    if (!isCorrectSoFar) {
      _resetGame();
      SnackBarUtils.showSnackBar(
        context,
        context.loc.testBackupErrorIncorrectOrder,
      );
      return;
    }

    setState(() => _selectedIndices.add(index));

    if (candidate.length == _mnemonic.length) {
      if (widget._providedMnemonic != null) {
        widget.onVerified!();
      } else {
        context.read<TestWalletBackupBloc>().add(
          VerifyPhysicalBackup(reorderedWords: candidate),
        );
      }
    }
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
        if (widget._providedMnemonic != null) {
          return _buildScreen(AppBar(title: Text(widget._title!)));
        }
        return BlocConsumer<TestWalletBackupBloc, TestWalletBackupState>(
          listenWhen: (previous, current) =>
              previous.selectedWallet?.id != current.selectedWallet?.id ||
              previous.verificationStatus != current.verificationStatus ||
              previous.failure != current.failure,
          listener: (context, state) {
            _syncSecret(state.selectedWallet?.localMasterFingerprints.single);
            if (state.failure case final failure?) {
              // With no wallet selected, no load is coming that would end the
              // spinner (e.g. LoadWallets itself failed), so end it here.
              if (state.selectedWallet == null) {
                setState(() => _unavailable = failure);
              }
              BullSnackBar.show(
                context,
                message: failure.toTranslated(context),
              );
              context.read<TestWalletBackupBloc>().add(const ClearFailure());
              return;
            }
            switch (state.verificationStatus) {
              case BackupVerificationStatus.success:
                context.read<TestWalletBackupBloc>().add(const ClearFailure());
                final onVerified = widget.onVerified;
                if (onVerified != null) {
                  onVerified();
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const BackupTestSuccessScreen(),
                    ),
                  );
                }
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

            return _buildScreen(
              PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: AppBarWidget(title: title),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScreen(PreferredSizeWidget appBar) {
    final nextWordNumber = _selectedIndices.length + 1;
    final showPrompt = _selectedIndices.length < _mnemonic.length;

    return Scaffold(
      backgroundColor: context.appColors.onSecondary,
      appBar: appBar,
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
                Column(
                  children: [
                    BBText(
                      context.loc.testBackupWhatIsWordNumber(nextWordNumber),
                      textAlign: .center,
                      style: context.font.labelMedium?.copyWith(
                        fontWeight: .w700,
                        color: context.appColors.outline,
                        letterSpacing: 0,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              else if (_mnemonic.isNotEmpty)
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
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ExcludeSemantics(
                  child: _ShuffledMnemonicGrid(
                    shuffled: _shuffled,
                    selectedIndices: _selectedIndices,
                    onWordTap: _onWordTap,
                  ),
                ),
            ],
          ),
        ),
      ),
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
          return BullText(
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
              BullText(
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
          onMistake: () => BullSnackBar.show(
            context,
            message: context.loc.testBackupErrorIncorrectOrder,
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
                  borderRadius: BorderRadius.circular(context.bullShapes.badge),
                ),
                child: Center(
                  child: BullText(
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
