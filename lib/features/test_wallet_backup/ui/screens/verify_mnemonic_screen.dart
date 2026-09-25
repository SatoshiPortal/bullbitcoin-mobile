import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/app_bar_widget.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/backup_test_success.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
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
  Future<Secret>? _secret;

  /// How far along the user is. A count, not the words — the phrase and the
  /// order the user is building both live inside `MnemonicChallenge`, which
  /// is why this screen no longer has a `_mnemonic` field.
  int _placed = 0;
  int _total = 0;

  late final Future<void> _privacyFuture = enableScreenPrivacy();

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
              previous.verificationStatus != current.verificationStatus ||
              (previous.statusError.isEmpty && current.statusError.isNotEmpty),
          listener: (context, state) {
            if (state.statusError.isNotEmpty) {
              SnackBarUtils.showSnackBar(context, state.statusError);
              context.read<TestWalletBackupBloc>().add(const ClearError());
              return;
            }
            switch (state.verificationStatus) {
              case BackupVerificationStatus.success:
                context.read<TestWalletBackupBloc>().add(const ClearError());
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
                        secret: _secret,
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
  const _Challenge({required this.secret, required this.onProgress});

  final Future<Secret>? secret;
  final void Function(int placed, int total) onProgress;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Secret>(
      future: secret,
      builder: (context, snapshot) {
        final value = snapshot.data;
        if (snapshot.hasError) {
          return BBText(
            context.loc.oopsSomethingWentWrong,
            textAlign: .center,
            style: context.font.bodyLarge?.copyWith(
              color: context.appColors.error,
            ),
          );
        }
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
          onFailure: (context, failure) => BBText(
            context.loc.oopsSomethingWentWrong,
            textAlign: .center,
            style: context.font.bodyLarge?.copyWith(
              color: context.appColors.error,
            ),
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
          layout: (context, tiles) => Column(
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
