import 'dart:async';

import 'package:screen_privacy/screen_privacy.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_master_key_info.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/dialog/blurred_dialog.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/all_seed_view/domain/all_seed_view_failure.dart';
import 'package:bb_mobile/features/all_seed_view/presentation/all_seed_view_cubit.dart';
import 'package:bb_mobile/features/all_seed_view/presentation/all_seed_view_failure_l10n.dart';
import 'package:bb_mobile/features/app_unlock/public/app_unlock_facade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AllSeedViewScreen extends StatefulWidget {
  final AppUnlockFacade appUnlockFacade;

  const AllSeedViewScreen({super.key, required this.appUnlockFacade});

  @override
  State<AllSeedViewScreen> createState() => _AllSeedViewScreenState();
}

class _AllSeedViewScreenState extends State<AllSeedViewScreen>
    with PrivacyScreen {
  /// Awaited before anything draws, like the show/verify screens: an
  /// un-awaited call leaves no guaranteed order between the first frame
  /// and the OS flag (Codex, 2026-09-17).
  late final Future<void> _privacyFuture = enableScreenPrivacy();

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Nothing draws until the OS flag call has returned (Codex, 2026-09-17:
    // a builder that ignores `connectionState` runs during `waiting`). The
    // service absorbs plugin errors itself, so completion is the most this
    // layer can wait for; that the flag took effect is a device test.
    return FutureBuilder<void>(
      future: _privacyFuture,
      builder: (context, snapshot) =>
          snapshot.connectionState == ConnectionState.done
          ? _body(context)
          : const SizedBox.shrink(),
    );
  }

  Widget _body(BuildContext context) {
    return BlocListener<AllSeedViewCubit, AllSeedViewState>(
      listenWhen: (p, c) => p.failure != c.failure,
      listener: (context, state) {
        if (state.failure case final failure?
            when failure is! AllSeedViewFetchFailure) {
          SnackBarUtils.showSnackBar(context, failure.toTranslated(context));
        }
      },
      child: BlocBuilder<AllSeedViewCubit, AllSeedViewState>(
        builder: (context, state) {
          // Viewing raw seed phrases exposes full custody of every wallet,
          // so it demands the same step-up re-authentication the app
          // already requires before changing the PIN. With no PIN set the
          // unlock screen succeeds immediately.
          if (!state.isUnlocked) {
            return widget.appUnlockFacade.buildReauthenticationGate(
              canPop: true,
              onSuccess: (grant) =>
                  context.read<AllSeedViewCubit>().unlock(grant),
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: BBText(
                context.loc.allSeedViewTitle,
                style: const TextStyle(fontWeight: .bold, fontSize: 20),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: state.loading
                    ? FadingLinearProgress(
                        height: 3,
                        trigger: state.loading,
                        backgroundColor: context.appColors.surface,
                        foregroundColor: context.appColors.primary,
                      )
                    : const SizedBox(height: 3),
              ),
            ),
            body: Builder(
              builder: (context) {
                if (state.loading) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: BBText(
                        context.loc.allSeedViewLoadingMessage,
                        style: context.font.bodyMedium,
                        color: context.appColors.onSurface.withValues(
                          alpha: 0.7,
                        ),
                        textAlign: .center,
                      ),
                    ),
                  );
                }
                if (state.failure is AllSeedViewFetchFailure) {
                  return Center(
                    child: BBText(
                      state.failure!.toTranslated(context),
                      style: context.font.bodyLarge,
                      color: context.appColors.error,
                    ),
                  );
                }
                if (state.allSeeds.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: BBText(
                        // Every entry unreadable is the fss9 cohort's screen:
                        // "no seeds" would be false and would read as loss.
                        state.unreadableEntries > 0
                            ? context.loc.allSeedViewUnreadableEntries(
                                state.unreadableEntries,
                              )
                            : context.loc.allSeedViewNoSeedsFound,
                        style: context.font.bodyLarge,
                        color: state.unreadableEntries > 0
                            ? context.appColors.error
                            : context.appColors.onSurface,
                        textAlign: .center,
                        maxLines: 3,
                      ),
                    ),
                  );
                }
                if (!state.seedsVisible) {
                  return SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: Icon(
                              Icons.visibility_off,
                              size: 120,
                              color: context.appColors.onSurface.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: BBButton.big(
                            label: context.loc.allSeedViewShowSeedsButton,
                            onPressed: () => _showWarningDialog(context),
                            bgColor: context.appColors.secondary,
                            textColor: context.appColors.onSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (state.unreadableEntries > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: BBText(
                          context.loc.allSeedViewUnreadableEntries(
                            state.unreadableEntries,
                          ),
                          style: context.font.bodyMedium,
                          color: context.appColors.error,
                          textAlign: .center,
                          maxLines: 3,
                        ),
                      ),
                    if (state.existingWallets.isNotEmpty) ...[
                      BBText(
                        context.loc.allSeedViewExistingWallets(
                          state.existingWallets.length,
                        ),
                        style: context.font.headlineSmall?.copyWith(
                          fontWeight: .bold,
                        ),
                        color: context.appColors.onSurface,
                      ),
                      const SizedBox(height: 8),
                      ...state.existingWallets.map<Widget>(
                        (seed) =>
                            _buildSeedCard(context, seed, isOldWallet: false),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (state.oldWallets.isNotEmpty) ...[
                      BBText(
                        context.loc.allSeedViewOldWallets(
                          state.oldWallets.length,
                        ),
                        style: context.font.headlineSmall?.copyWith(
                          fontWeight: .bold,
                        ),
                        color: context.appColors.onSurface,
                      ),
                      const SizedBox(height: 8),
                      ...state.oldWallets.map<Widget>(
                        (seed) =>
                            _buildSeedCard(context, seed, isOldWallet: true),
                      ),
                    ],
                    if (state.swapMasterKey != null) ...[
                      const SizedBox(height: 24),
                      BBText(
                        'Swap mnemonic',
                        style: context.font.headlineSmall?.copyWith(
                          fontWeight: .bold,
                        ),
                        color: context.appColors.onSurface,
                      ),
                      const SizedBox(height: 8),
                      _buildSwapKeyCard(context, state.swapMasterKey!),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showWarningDialog(BuildContext context) {
    return BlurredDialog.show<void>(
      context: context,
      isDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appColors.surface,
        title: Text(
          context.loc.allSeedViewSecurityWarningTitle,
          style: context.font.headlineSmall?.copyWith(
            color: context.appColors.onSurface,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            context.loc.allSeedViewSecurityWarningMessage,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurface,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              context.loc.cancel,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<AllSeedViewCubit>().showSeeds();
            },
            child: Text(
              context.loc.allSeedViewIUnderstandButton,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.primary,
                fontWeight: .bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteWarningDialog(BuildContext context, Secret seed) {
    return BlurredDialog.show<void>(
      context: context,
      isDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appColors.surface,
        title: Text(
          context.loc.allSeedViewDeleteWarningTitle,
          style: context.font.headlineSmall?.copyWith(
            color: context.appColors.error,
            fontWeight: .bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            context.loc.allSeedViewDeleteWarningMessage,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurface,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              context.loc.cancel,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<AllSeedViewCubit>().deleteSeed(seed.id.hex);
            },
            child: Text(
              context.loc.delete,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.error,
                fontWeight: .bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteSwapWarningDialog(BuildContext context) {
    return BlurredDialog.show<void>(
      context: context,
      isDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appColors.surface,
        title: Text(
          'Delete swap mnemonic?',
          style: context.font.headlineSmall?.copyWith(
            color: context.appColors.error,
            fontWeight: .bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            'This removes the swap master key from secure storage. It will be '
            're-derived from your wallet seed the next time the app needs it, '
            'with the same fingerprint. Ongoing swaps are unaffected.',
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurface,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              context.loc.cancel,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<AllSeedViewCubit>().deleteSwapMnemonic();
            },
            child: Text(
              context.loc.delete,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.error,
                fontWeight: .bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwapKeyCard(BuildContext context, SwapMasterKeyInfo swapKey) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.appColors.outline, width: 1),
        ),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Row(
              crossAxisAlignment: .start,
              children: [
                const Expanded(child: _SwapMnemonicView()),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: context.appColors.error,
                  ),
                  onPressed: () => _showDeleteSwapWarningDialog(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            BBText(
              'Fingerprint: ${swapKey.fingerprint} (${swapKey.network})',
              style: context.font.bodyMedium,
              color: context.appColors.onSurface.withValues(alpha: 0.7),
            ),
            BBText(
              'Linked wallet: ${swapKey.walletFingerprint}',
              style: context.font.bodyMedium,
              color: context.appColors.onSurface.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeedCard(
    BuildContext context,
    Secret seed, {
    required bool isOldWallet,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.appColors.outline, width: 1),
            ),
            child: Row(
              crossAxisAlignment: .start,
              children: [
                Expanded(
                  // Sealed: the words are read and rendered inside the package's widget and never reach this screen or the cubit's state.
                  child: MnemonicView(
                    // Keyed by identity so a reordered list never hands one secret's state to another's card.
                    key: ValueKey(seed.id.hex),
                    secret: seed,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.onSurface,
                    ),
                    passphraseLabel: context.loc.allSeedViewPassphraseLabel,
                    passphraseLabelStyle: context.font.bodyLarge?.copyWith(
                      color: context.appColors.onSurface,
                    ),
                    onFailure: (context, failure) => BBText(
                      AllSeedViewFetchFailure(
                        failure.logMessage,
                      ).toTranslated(context),
                      style: context.font.bodyMedium,
                      color: context.appColors.error,
                    ),
                  ),
                ),
                if (isOldWallet) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: context.appColors.error,
                    ),
                    onPressed: () => _showDeleteWarningDialog(context, seed),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The swap mnemonic, read where it is drawn and held nowhere.
///
/// The sealed-display shape `secrets` uses for wallet seeds, applied to a
/// credential that belongs to `swaps`: the words are not in cubit state, and
/// they are kept out of the semantics tree an accessibility service walks.
class _SwapMnemonicView extends StatefulWidget {
  const _SwapMnemonicView();

  @override
  State<_SwapMnemonicView> createState() => _SwapMnemonicViewState();
}

class _SwapMnemonicViewState extends State<_SwapMnemonicView> {
  late final Future<String?> _mnemonic = context
      .read<AllSeedViewCubit>()
      .loadSwapMnemonic();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: FutureBuilder<String?>(
        future: _mnemonic,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(height: 20);
          }
          final words = snapshot.data;
          if (words == null || words.isEmpty) {
            return BBText(
              context.loc.oopsSomethingWentWrong,
              style: context.font.bodyMedium,
              color: context.appColors.error,
            );
          }
          return BBText(
            words,
            style: context.font.bodyMedium,
            color: context.appColors.onSurface,
            maxLines: 5,
          );
        },
      ),
    );
  }
}
