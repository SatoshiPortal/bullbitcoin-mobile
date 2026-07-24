import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/core/widgets/warning_bottom_sheet.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/bitcoin_sync_backend_cubit.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullSyncProgress, BullSyncProgressStatus;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Developer-only wallet option: lets a Bitcoin wallet opt into a
/// foreground compact block filter (BIP157/158) sync instead of Electrum.
///
/// Only meant to be shown when the selected wallet is a Bitcoin wallet and
/// either developer mode is enabled or the build was compiled with
/// `--dart-define=ENABLE_CBF=true` — the caller (`WalletOptionsScreen`) is
/// responsible for that gate and for providing a `BitcoinSyncBackendCubit`
/// scoped to the wallet's id above this widget. Toggling this tile still
/// goes through `CheckCompactBlockFiltersAvailableUsecase` at sync time
/// (`WalletSyncRoutingRepository`), so a visible-but-unavailable build
/// (e.g. Tor enabled) surfaces a failed sync rather than silently doing
/// nothing.
class BitcoinSyncBackendTile extends StatelessWidget {
  const BitcoinSyncBackendTile({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BitcoinSyncBackendCubit>().state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // MergeSemantics + an explicit `toggled` flag so assistive tech
        // announces this as a single switch control, and the whole row —
        // not just the small Switch hit target — toggles it.
        MergeSemantics(
          child: Semantics(
            toggled: state.isCompactBlockFiltersEnabled,
            child: SettingsEntryItem(
              icon: Icons.filter_alt_outlined,
              title: context.loc.walletOptionsSyncBackendTileTitle,
              onTap: state.isLoading
                  ? null
                  : () => _onToggled(
                      context,
                      !state.isCompactBlockFiltersEnabled,
                    ),
              trailing: Switch(
                value: state.isCompactBlockFiltersEnabled,
                onChanged: state.isLoading
                    ? null
                    : (enable) => _onToggled(context, enable),
              ),
            ),
          ),
        ),
        if (state.isCompactBlockFiltersEnabled &&
            state.phase != BitcoinSyncBackendPhase.idle)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _SyncProgressSection(state: state),
          ),
      ],
    );
  }

  Future<void> _onToggled(BuildContext context, bool enable) {
    final cubit = context.read<BitcoinSyncBackendCubit>();
    if (!enable) return cubit.disableCompactBlockFilters();

    return WarningBottomSheet.show(
      context,
      title: context.loc.walletOptionsSyncBackendWarningTitle,
      message: context.loc.walletOptionsSyncBackendWarningMessage,
      confirmLabel: context.loc.walletOptionsSyncBackendWarningConfirmButton,
      onConfirm: cubit.enableCompactBlockFilters,
    );
  }
}

class _SyncProgressSection extends StatelessWidget {
  const _SyncProgressSection({required this.state});

  final BitcoinSyncBackendState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BullSyncProgress(
          label: _label(context),
          status: _status,
          percent: state.phase == BitcoinSyncBackendPhase.scanning
              ? state.scannedPercent
              : null,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Turning off here is the same backend-revert action as the
            // Switch above — labeled "Turn off" (not "Cancel") so it never
            // reads as merely pausing this one attempt.
            if (state.isSyncing)
              BBButton.small(
                label: context.loc.walletOptionsSyncBackendTurnOffButton,
                onPressed: () =>
                    context.read<BitcoinSyncBackendCubit>().cancel(),
                outlined: true,
                bgColor: context.appColors.transparent,
                textColor: context.appColors.onSurface,
                borderColor: context.appColors.border,
              ),
            if (state.canRetry)
              BBButton.small(
                label: context.loc.walletOptionsSyncBackendRetryButton,
                onPressed: () =>
                    context.read<BitcoinSyncBackendCubit>().retry(),
                bgColor: context.appColors.primary,
                textColor: context.appColors.onPrimary,
              ),
          ],
        ),
      ],
    );
  }

  BullSyncProgressStatus get _status => switch (state.phase) {
    BitcoinSyncBackendPhase.completed => BullSyncProgressStatus.completed,
    BitcoinSyncBackendPhase.failed => BullSyncProgressStatus.failed,
    BitcoinSyncBackendPhase.idle ||
    BitcoinSyncBackendPhase.connecting ||
    BitcoinSyncBackendPhase.scanning => BullSyncProgressStatus.active,
  };

  String _label(BuildContext context) => switch (state.phase) {
    BitcoinSyncBackendPhase.idle || BitcoinSyncBackendPhase.connecting =>
      context.loc.walletOptionsSyncBackendStatusConnecting,
    BitcoinSyncBackendPhase.scanning =>
      state.scannedPercent == null
          ? context.loc.walletOptionsSyncBackendStatusScanning
          : context.loc.walletOptionsSyncBackendStatusScanningPercent(
              '${state.scannedPercent!.round()}',
            ),
    BitcoinSyncBackendPhase.completed =>
      context.loc.walletOptionsSyncBackendStatusCompleted,
    // Never the raw failure detail — one of three generic, translated
    // messages picked by BitcoinSyncBackendFailureReason (see
    // BitcoinSyncBackendCubit._failureReasonFor).
    BitcoinSyncBackendPhase.failed => switch (state.failureReason) {
      BitcoinSyncBackendFailureReason.torUnsupported =>
        context.loc.walletOptionsSyncBackendStatusFailedTorUnsupported,
      BitcoinSyncBackendFailureReason.gateClosed =>
        context.loc.walletOptionsSyncBackendStatusFailedUnavailable,
      BitcoinSyncBackendFailureReason.retriable ||
      null => context.loc.walletOptionsSyncBackendStatusFailed,
    },
  };
}
