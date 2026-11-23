import 'dart:async';

import 'package:screen_privacy/screen_privacy.dart';
import 'package:secrets/secrets.dart';
import 'package:swaps/swaps.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/all_seed_view/domain/all_seed_view_failure.dart';
import 'package:bb_mobile/features/all_seed_view/presentation/all_seed_view_cubit.dart';
import 'package:bb_mobile/features/all_seed_view/presentation/all_seed_view_failure_l10n.dart';
import 'package:access/access.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButtonSize,
        BullConfirmDialog,
        BullButton,
        BullFadingLinearProgress,
        BullScreenPrivacyGate,
        BullShapesX,
        BullSnackBar,
        BullText,
        BullTypographyX,
        Gap;

class AllSeedViewScreen extends StatefulWidget {
  final Access access;

  const AllSeedViewScreen({super.key, required this.access});

  @override
  State<AllSeedViewScreen> createState() => _AllSeedViewScreenState();
}

class _AllSeedViewScreenState extends State<AllSeedViewScreen>
    with PrivacyScreen, WidgetsBindingObserver {
  /// Awaited before anything draws, like the show/verify screens: an
  /// un-awaited call leaves no guaranteed order between the first frame
  /// and the OS flag (Codex, 2026-09-17).
  late Future<bool> _privacyFuture = enableScreenPrivacy();
  final Set<String> _shownPassphrases = {};
  int _revealGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _revealGeneration++;
      if (_shownPassphrases.isNotEmpty) setState(_shownPassphrases.clear);
    }
  }

  Future<void> _togglePassphrase(Secret seed) async {
    final id = seed.id.hex;
    if (_shownPassphrases.contains(id)) {
      setState(() => _shownPassphrases.remove(id));
      return;
    }
    final generation = ++_revealGeneration;
    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (gateContext) => widget.access.buildReauthenticationGate(
          canPop: true,
          onSuccess: (_) => Navigator.of(gateContext).pop(true),
        ),
      ),
    );
    if (!mounted || accepted != true || generation != _revealGeneration) return;
    final state = context.read<AllSeedViewCubit>().state;
    if (!state.isUnlocked ||
        !state.seedsVisible ||
        !state.allSeeds.any((current) => current.id == seed.id)) {
      return;
    }
    setState(() => _shownPassphrases.add(id));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Nothing draws before capture blocking is confirmed: the gate waits for
    // the OS flag and hides the seeds if the platform refused it.
    return BullScreenPrivacyGate(
      unavailableMessage: context.loc.screenPrivacyUnavailable,
      retryLabel: context.loc.retry,
      protection: _privacyFuture,
      onRetry: () => setState(() {
        _privacyFuture = enableScreenPrivacy();
      }),
      builder: _body,
    );
  }

  Widget _body(BuildContext context) {
    return BlocListener<AllSeedViewCubit, AllSeedViewState>(
      listenWhen: (p, c) => p.failure != c.failure,
      listener: (context, state) {
        if (state.failure case final failure?
            when failure is! AllSeedViewFetchFailure) {
          BullSnackBar.show(context, message: failure.toTranslated(context));
        }
      },
      child: BlocBuilder<AllSeedViewCubit, AllSeedViewState>(
        builder: (context, state) {
          // Viewing raw seed phrases exposes full custody of every wallet,
          // so it demands the same step-up re-authentication the app
          // already requires before changing the PIN. With no PIN set the
          // unlock screen succeeds immediately.
          if (!state.isUnlocked) {
            return widget.access.buildReauthenticationGate(
              canPop: true,
              onSuccess: (grant) =>
                  context.read<AllSeedViewCubit>().unlock(grant),
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: BullText(
                context.loc.allSeedViewTitle,
                style: context.bullType.subtitle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: state.loading
                    ? BullFadingLinearProgress(
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
                      child: BullText(
                        context.loc.allSeedViewLoadingMessage,
                        style: context.bullType.body,
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
                    child: BullText(
                      state.failure!.toTranslated(context),
                      style: context.bullType.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      color: context.appColors.error,
                    ),
                  );
                }
                if (state.allSeeds.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: BullText(
                        // Every entry unreadable is the fss9 cohort's screen:
                        // "no seeds" would be false and would read as loss.
                        state.unreadableEntries > 0
                            ? context.loc.allSeedViewUnreadableEntries(
                                state.unreadableEntries,
                              )
                            : context.loc.allSeedViewNoSeedsFound,
                        style: context.bullType.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
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
                          child: BullButton.secondary(
                            label: context.loc.allSeedViewShowSeedsButton,
                            onPressed: () => _showWarningDialog(context),
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
                        child: BullText(
                          context.loc.allSeedViewUnreadableEntries(
                            state.unreadableEntries,
                          ),
                          style: context.bullType.body,
                          color: context.appColors.error,
                          textAlign: .center,
                          maxLines: 3,
                        ),
                      ),
                    if (state.existingWallets.isNotEmpty) ...[
                      BullText(
                        context.loc.allSeedViewExistingWallets(
                          state.existingWallets.length,
                        ),
                        style: context.bullType.subtitle
                            .copyWith(fontWeight: FontWeight.w400)
                            .copyWith(fontWeight: .bold),
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
                      BullText(
                        context.loc.allSeedViewOldWallets(
                          state.oldWallets.length,
                        ),
                        style: context.bullType.subtitle
                            .copyWith(fontWeight: FontWeight.w400)
                            .copyWith(fontWeight: .bold),
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
                      BullText(
                        context.loc.allSeedViewSwapMnemonicTitle,
                        style: context.bullType.subtitle
                            .copyWith(fontWeight: FontWeight.w400)
                            .copyWith(fontWeight: .bold),
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

  Future<void> _showWarningDialog(BuildContext context) async {
    final confirmed = await BullConfirmDialog.show(
      context,
      title: context.loc.allSeedViewSecurityWarningTitle,
      message: context.loc.allSeedViewSecurityWarningMessage,
      confirmLabel: context.loc.allSeedViewIUnderstandButton,
      cancelLabel: context.loc.cancel,
      isDismissible: false,
    );
    if (confirmed && context.mounted) {
      context.read<AllSeedViewCubit>().showSeeds();
    }
  }

  Future<void> _showDeleteWarningDialog(
    BuildContext context,
    Secret seed,
  ) async {
    final confirmed = await BullConfirmDialog.show(
      context,
      title: context.loc.allSeedViewDeleteWarningTitle,
      message: context.loc.allSeedViewDeleteWarningMessage,
      confirmLabel: context.loc.delete,
      cancelLabel: context.loc.cancel,
      destructive: true,
      isDismissible: false,
    );
    if (confirmed && context.mounted) {
      context.read<AllSeedViewCubit>().deleteSeed(seed.id.hex);
    }
  }

  Future<void> _showDeleteSwapWarningDialog(BuildContext context) async {
    final confirmed = await BullConfirmDialog.show(
      context,
      title: context.loc.allSeedViewDeleteSwapMnemonicTitle,
      message: context.loc.allSeedViewDeleteSwapMnemonicMessage,
      confirmLabel: context.loc.delete,
      cancelLabel: context.loc.cancel,
      destructive: true,
      isDismissible: false,
    );
    if (confirmed && context.mounted) {
      context.read<AllSeedViewCubit>().deleteSwapMnemonic();
    }
  }

  Widget _buildSwapKeyCard(BuildContext context, SwapMasterKeyInfo swapKey) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(context.bullShapes.card),
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
            BullText(
              context.loc.allSeedViewSwapFingerprint(
                swapKey.fingerprint,
                swapKey.network,
              ),
              style: context.bullType.body,
              color: context.appColors.onSurface.withValues(alpha: 0.7),
            ),
            BullText(
              context.loc.allSeedViewSwapLinkedWallet(
                swapKey.walletFingerprint,
              ),
              style: context.bullType.body,
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
              borderRadius: BorderRadius.circular(context.bullShapes.card),
              border: Border.all(color: context.appColors.outline, width: 1),
            ),
            child: Row(
              crossAxisAlignment: .start,
              children: [
                Expanded(
                  // Sealed: the words are read and rendered inside the package's widget and never reach this screen or the cubit's state.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      seed.widgets.mnemonicView(
                        showPassphrase: _shownPassphrases.contains(seed.id.hex),
                        // Keyed by identity so a reordered list never hands one secret's state to another's card.
                        key: ValueKey(seed.id.hex),
                        style: context.bullType.body.copyWith(
                          color: context.appColors.onSurface,
                        ),
                        passphraseLabel: context.loc.allSeedViewPassphraseLabel,
                        passphraseLabelStyle: context.bullType.body
                            .copyWith(fontWeight: FontWeight.w500)
                            .copyWith(color: context.appColors.onSurface),
                        failureBuilder: (context, failure, retry) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BullText(
                              AllSeedViewFetchFailure(failure.logMessage)
                                  .toTranslated(context),
                              style: context.bullType.body,
                              color: context.appColors.error,
                            ),
                            const Gap(16),
                            BullButton.secondary(
                              size: BullButtonSize.small,
                              label: context.loc.retry,
                              onPressed: retry,
                            ),
                          ],
                        ),
                      ),
                      if (seed.info.hasPassphrase) ...[
                        Text(context.loc.passphraseWordsIncompleteWarning),
                        TextButton(
                          onPressed: () => _togglePassphrase(seed),
                          child: Text(
                            _shownPassphrases.contains(seed.id.hex)
                                ? context.loc.passphraseHide
                                : context.loc.passphraseShow,
                          ),
                        ),
                      ],
                    ],
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
            return BullText(
              context.loc.oopsSomethingWentWrong,
              style: context.bullType.body,
              color: context.appColors.error,
            );
          }
          return BullText(
            words,
            style: context.bullType.body,
            color: context.appColors.onSurface,
            maxLines: 5,
          );
        },
      ),
    );
  }
}
