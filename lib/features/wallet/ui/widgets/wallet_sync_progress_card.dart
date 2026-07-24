import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_sync_progress_cubit.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullSyncProgress, BullSyncProgressStatus;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

/// Foreground compact-block-filter (CBF) sync progress for one wallet,
/// shown on `WalletDetailScreen` above the transaction list.
///
/// Renders nothing for an ordinary Electrum sync, and nothing once no
/// attempt is tracked for [walletId] — see
/// `WalletSyncProgressEntry.isConfirmedCbf`: this card only ever appears
/// once the tracked attempt is confirmed CBF (its `WalletSyncStarted`
/// carried that backend, or — for a signal that can arrive with no
/// preceding tracked Started, like a setup failure — the signal itself is
/// CBF-tagged). Never renders a raw warning/failure message or any
/// peer/backend detail — only the generic, translated status text
/// `BullSyncProgress` already shows, plus a Retry control once the attempt
/// has failed. Deliberately no "stop"/"cancel" control while the attempt is
/// active: `CbfWalletDatasource` runs a long-lived session that keeps going
/// once started (only wallet deletion or a mid-session Tor-enable ever
/// tear one down — see that class's session lifecycle policy), so
/// `WalletSyncProgressCubit.cancel` would be a no-op here and offering the
/// control would misrepresent it as able to stop the sync. Reads the
/// app-wide `WalletSyncProgressCubit` singleton provided by `WalletRouter`.
class WalletSyncProgressCard extends StatelessWidget {
  const WalletSyncProgressCard({super.key, required this.walletId});

  final String walletId;

  @override
  Widget build(BuildContext context) {
    final entry = context.select(
      (WalletSyncProgressCubit cubit) => cubit.state.forWallet(walletId),
    );
    if (entry == null || !entry.isConfirmedCbf) return const SizedBox.shrink();

    final isActive =
        entry.phase == WalletSyncProgressPhase.connecting ||
        entry.phase == WalletSyncProgressPhase.scanning;
    final isFailed = entry.phase == WalletSyncProgressPhase.failed;
    final radius = BorderRadius.circular(2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appColors.cardBackground,
          borderRadius: radius,
          border: Border.all(color: context.appColors.border),
          boxShadow: [
            BoxShadow(
              color: context.appColors.scrim,
              offset: const Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            BBText(
              context.loc.walletOptionsSyncBackendTileTitle,
              style: context.font.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(8),
            _StageProgress(entry: entry),
            if (isActive) ...[const Gap(10), _Diagnostics(entry: entry)],
            if (entry.hasWarning && isActive) ...[
              const Gap(6),
              BBText(
                context.loc.walletSyncProgressNonFatalNotice,
                style: context.font.labelMedium,
                color: context.appColors.textMuted,
              ),
            ],
            if (isFailed) ...[
              const Gap(8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  BBButton.small(
                    label: context.loc.walletOptionsSyncBackendRetryButton,
                    onPressed: () =>
                        context.read<WalletSyncProgressCubit>().retry(walletId),
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StageProgress extends StatelessWidget {
  const _StageProgress({required this.entry});

  final WalletSyncProgressEntry entry;

  @override
  Widget build(BuildContext context) {
    final completed = entry.phase == WalletSyncProgressPhase.completed;
    final failed = entry.phase == WalletSyncProgressPhase.failed;
    final currentStage = _currentStage(entry);
    final stages = <Widget>[
      BullSyncProgress(
        label: entry.peerHandshakeCount > 0
            ? context.loc.walletSyncProgressPeerHandshakes(
                entry.peerHandshakeCount,
              )
            : entry.hasConnected
            ? context.loc.walletSyncProgressStageConnected
            : context.loc.walletSyncProgressStageConnecting,
        status: _statusForStage(
          stage: 0,
          currentStage: currentStage,
          syncCompleted: completed,
          syncFailed: failed,
        ),
      ),
      BullSyncProgress(
        label: entry.chainHeight == null
            ? context.loc.walletSyncProgressStageSyncingHeaders
            : context.loc.walletSyncProgressChainHeight(entry.chainHeight!),
        status: _statusForStage(
          stage: 1,
          currentStage: currentStage,
          syncCompleted: completed,
          syncFailed: failed,
        ),
      ),
      BullSyncProgress(
        label: context.loc.walletSyncProgressStageDownloadingFilters,
        status: _statusForStage(
          stage: 2,
          currentStage: currentStage,
          syncCompleted: completed,
          syncFailed: failed,
        ),
        percent: currentStage == 2 ? entry.scannedPercent : null,
      ),
      BullSyncProgress(
        label: entry.receivedBlockCount == 0
            ? context.loc.walletSyncProgressStageMatchingBlocks
            : context.loc.walletSyncProgressBlocksMatched(
                entry.receivedBlockCount,
              ),
        status: _statusForStage(
          stage: 3,
          currentStage: currentStage,
          syncCompleted: completed,
          syncFailed: failed,
        ),
      ),
      BullSyncProgress(
        label: context.loc.walletSyncProgressStageApplyingUpdate,
        status: _statusForStage(
          stage: 4,
          currentStage: currentStage,
          syncCompleted: completed,
          syncFailed: failed,
        ),
      ),
    ];

    return Column(
      children: [
        for (var index = 0; index < stages.length; index++) ...[
          if (index > 0) const Gap(12),
          stages[index],
        ],
      ],
    );
  }

  int _currentStage(WalletSyncProgressEntry entry) => switch (entry.scanStage) {
    null || WalletSyncScanStage.connecting => 0,
    WalletSyncScanStage.connected || WalletSyncScanStage.syncingHeaders => 1,
    WalletSyncScanStage.downloadingFilters => 2,
    WalletSyncScanStage.matchingBlocks => 3,
    WalletSyncScanStage.applyingUpdate => 4,
  };

  BullSyncProgressStatus _statusForStage({
    required int stage,
    required int currentStage,
    required bool syncCompleted,
    required bool syncFailed,
  }) {
    if (syncCompleted || stage < currentStage) {
      return BullSyncProgressStatus.completed;
    }
    if (stage > currentStage) return BullSyncProgressStatus.pending;
    if (syncFailed) return BullSyncProgressStatus.failed;
    return BullSyncProgressStatus.active;
  }
}

class _Diagnostics extends StatelessWidget {
  const _Diagnostics({required this.entry});

  final WalletSyncProgressEntry entry;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (entry.hasConnected) context.loc.walletSyncProgressConnected,
      if (entry.hasFilterProgress) context.loc.walletSyncProgressFiltersStarted,
      // A local header height only — never rendered as a percentage or
      // compared against a target height, see WalletSyncScanStage
      // .syncingHeaders's doc.
      if (entry.chainHeight != null)
        context.loc.walletSyncProgressChainHeight(entry.chainHeight!),
      if (entry.receivedBlockCount > 0)
        context.loc.walletSyncProgressBlocksMatched(entry.receivedBlockCount),
      if (entry.hasReachedApplyingUpdate)
        context.loc.walletSyncProgressApplyingUpdate,
    ];
    if (details.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          context.loc.walletSyncProgressDiagnosticsTitle,
          style: context.font.labelMedium,
          color: context.appColors.textMuted,
        ),
        const Gap(4),
        for (final detail in details)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: BBText(
              detail,
              style: context.font.labelMedium,
              color: context.appColors.textMuted,
            ),
          ),
      ],
    );
  }
}
