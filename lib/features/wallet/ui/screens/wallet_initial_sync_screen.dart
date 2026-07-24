import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/progress_screen.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_initial_sync_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_sync_progress_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// The very first screen a compact-block-filter (CBF) wallet's owner sees
/// after a recovery/import operation, reached only through
/// `WalletRouter.goToWalletHomeOrInitialSync`/
/// `goToWalletHomeOrInitialSyncForDefaultBitcoinWallet` once those helpers
/// confirm both that the operation is a recovery/import (their
/// `isRecoveryOrImport` flag — never a newly created wallet) and that the
/// wallet's persisted `BitcoinSyncBackend` is
/// `BitcoinSyncBackend.compactBlockFilters`; every other case keeps going
/// straight to `WalletRoute.walletHome` and never sees this screen.
///
/// Continue/Skip gating comes from the route-scoped `WalletInitialSyncCubit`
/// `WalletRouter` provides above this screen — a fresh instance per visit
/// that owns actually starting (and, on retry, restarting) this wallet's
/// first CBF attempt; this screen itself never calls `StartWalletSyncUsecase`.
///
/// Renders the exact same app-wide `WalletSyncProgressCard` shown later on
/// `WalletDetailScreen`/the settings tile for the attempt's staged
/// diagnostics — this screen adds no new progress/diagnostics model of its
/// own, only a dedicated first-run presentation of the existing one, fed by
/// the app-wide `WalletSyncProgressCubit` singleton `WalletRouter` still
/// threads through this route via `BlocProvider.value`. The card's own
/// Retry button (wired to that singleton) is preserved unchanged — its
/// resulting progress events reach `WalletInitialSyncCubit` too, since both
/// subscribe to the same underlying stream.
///
/// "Continue" is enabled once the tracked attempt reaches
/// [WalletInitialSyncPhase.completed]. A [WalletInitialSyncPhase.failed]
/// attempt instead offers an explicit "Skip" alongside the card's own
/// Retry, so leaving before the first sync finishes is always a
/// deliberate, visible choice — never a silent redirect. The system back
/// gesture and any other app navigation are never intercepted here; only
/// this screen's own Continue/Skip action is gated on the tracked phase.
/// Deliberately no "stop"/"cancel" control — see `WalletSyncProgressCard`'s
/// doc for why one would be a no-op under CBF's long-lived session policy.
///
/// While the attempt is still running, this screen also states — via
/// [context.loc.walletInitialSyncBackgroundNotice] — that leaving it (or
/// the app) never cancels the sync: `CbfWalletDatasource` runs a
/// long-lived session with no lifecycle-driven teardown of its own (only
/// wallet deletion or a mid-session Tor-enable ever tear one down — see
/// `WalletSyncProgressCard`'s doc), so this is an accurate statement, not
/// an aspirational one — there is no automatic-cancel-on-lifecycle-event
/// behavior anywhere in this path for this screen to describe otherwise.
class WalletInitialSyncScreen extends StatelessWidget {
  const WalletInitialSyncScreen({super.key, required this.walletId});

  final String walletId;

  void _continueToWalletHome(BuildContext context) =>
      context.goNamed(WalletRoute.walletHome.name);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletInitialSyncCubit, WalletInitialSyncState>(
      builder: (context, state) {
        final completed = state.isCompleted;
        final failed = state.isFailed;
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const Gap(24),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!completed && !failed)
                            const ProgressScreen(isLoading: true),
                          const Gap(16),
                          WalletSyncProgressCard(walletId: walletId),
                          if (!completed) ...[
                            const Gap(12),
                            BBText(
                              context.loc.walletInitialSyncBackgroundNotice,
                              style: context.font.labelMedium,
                              color: context.appColors.textMuted,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Gap(16),
                  if (completed)
                    SizedBox(
                      width: double.infinity,
                      child: BBButton.big(
                        label: context.loc.continueButton,
                        onPressed: () => _continueToWalletHome(context),
                        bgColor: context.appColors.primary,
                        textColor: context.appColors.onPrimary,
                      ),
                    )
                  else if (failed)
                    SizedBox(
                      width: double.infinity,
                      child: BBButton.big(
                        label: context.loc.wizardSkipButton,
                        onPressed: () => _continueToWalletHome(context),
                        outlined: true,
                        bgColor: context.appColors.transparent,
                        textColor: context.appColors.onSurface,
                        borderColor: context.appColors.border,
                      ),
                    ),
                  const Gap(16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
