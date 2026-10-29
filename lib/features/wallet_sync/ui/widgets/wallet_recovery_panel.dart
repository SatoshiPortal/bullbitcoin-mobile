import 'dart:async';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:intl/intl.dart';
import '../../domain/wallet_sync_status.dart';
import 'package:transaction_sync/transaction_sync.dart';
import '../../domain/wallet_sync_options_failure.dart';
import '../../presentation/wallet_sync_status_l10n.dart';

class WalletRecoveryPanel extends StatefulWidget {
  final WalletSyncStatus status;
  final VoidCallback onRetry;
  final VoidCallback onSettings;
  final VoidCallback onTorSettings;
  final VoidCallback? onContinueOnMobileData;
  final DateTime Function()? now;

  const WalletRecoveryPanel({
    super.key,
    required this.status,
    required this.onRetry,
    required this.onSettings,
    required this.onTorSettings,
    this.onContinueOnMobileData,
    this.now,
  });

  @override
  State<WalletRecoveryPanel> createState() => _WalletRecoveryPanelState();
}

class _WalletRecoveryPanelState extends State<WalletRecoveryPanel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    if (!status.isPrivate) return const SizedBox.shrink();
    final now = widget.now?.call() ?? DateTime.now().toUtc();
    if (!status.incomplete &&
        status.failure == null &&
        !status.emptyRecovery &&
        status.networkPolicy?.pauseReason == null) {
      return const SizedBox.shrink();
    }
    final message = status.message(context, now);
    final fraction = status.progress?.fraction;
    final percent = ((fraction ?? 0) * 100 ~/ 10) * 10;
    final checked = status.checkedBlocks;
    final total = status.totalBlocks;
    final minutes = status.etaAt(now);
    final date = status.scanDate;
    final networkPause = status.networkPolicy?.pauseReason;
    return Padding(
      padding: const EdgeInsets.all(BullSpacing.md),
      child: BullBorderedTile(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              label: context.loc.syncProgressSemantics(message, percent),
              child: const SizedBox.shrink(),
            ),
            BullText(
              status.emptyRecovery &&
                      status.failure == null &&
                      date != null &&
                      networkPause == null
                  ? context.loc.syncNoTransactions(
                      DateFormat.yMMMM(context.loc.localeName).format(date),
                    )
                  : message,
              style: context.bullText.bodyMedium,
            ),
            if (status.incomplete) ...[
              const Gap(BullSpacing.md),
              if (status.failure == null && networkPause == null)
                BullFadingLinearProgress(
                  trigger: true,
                  value: fraction?.clamp(0, 0.999999),
                  height: BullSpacing.xxs,
                  backgroundColor: context.bull.surface,
                  foregroundColor: context.bull.primary,
                ),
              if (checked != null && total != null) ...[
                const Gap(BullSpacing.sm),
                BullText(
                  context.loc.syncBlocksChecked(checked, total),
                  style: context.bullText.bodySmall,
                ),
              ],
              const Gap(BullSpacing.sm),
              BullText(
                context.loc.syncIncomplete,
                style: context.bullText.bodySmall,
              ),
              if (minutes != null)
                BullText(
                  context.loc.syncEtaMinutes(minutes),
                  style: context.bullText.bodySmall,
                ),
              const Gap(BullSpacing.sm),
              if (networkPause == null)
                BullText(
                  context.loc.syncKeepOpen,
                  style: context.bullText.bodySmall,
                ),
            ],
            if ((networkPause, widget.onContinueOnMobileData) case (
              CbfNetworkPauseReason.mobileData,
              final resume?,
            )) ...[
              const Gap(BullSpacing.md),
              BullButton.big(
                label: context.loc.syncContinueMobileData,
                onPressed: resume,
                bgColor: context.bull.primary,
                textColor: context.bull.onPrimary,
              ),
            ],
            if (status.failure != null && networkPause == null) ...[
              const Gap(BullSpacing.md),
              BullButton.big(
                label: context.loc.retry,
                onPressed: widget.onRetry,
                bgColor: context.bull.primary,
                textColor: context.bull.onPrimary,
              ),
            ],
            if (status.failure != null ||
                status.emptyRecovery ||
                networkPause != null) ...[
              const Gap(BullSpacing.sm),
              BullButton.big(
                label:
                    networkPause == null &&
                        status.failure is WalletSyncTorFailure
                    ? context.loc.syncTorAction
                    : context.loc.syncSettingsAction,
                onPressed:
                    networkPause == null &&
                        status.failure is WalletSyncTorFailure
                    ? widget.onTorSettings
                    : widget.onSettings,
                bgColor: context.bull.surface,
                textColor: context.bull.primary,
                outlined: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WalletIncompleteBalance extends StatelessWidget {
  final WalletSyncStatus status;
  final bool sending;
  final VoidCallback? onContinueOnMobileData;
  final VoidCallback? onSettings;
  const WalletIncompleteBalance({
    super.key,
    required this.status,
    this.sending = false,
    this.onContinueOnMobileData,
    this.onSettings,
  });
  @override
  Widget build(BuildContext context) =>
      (status.incomplete ||
          (!sending &&
              status.isPrivate &&
              status.networkPolicy?.pauseReason != null))
      ? Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BullSpacing.md,
            vertical: BullSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (status.networkPolicy?.pauseReason == null)
                    BullCircularProgress(
                      value: status.progress?.fraction,
                      color: context.bull.onSurface,
                      semanticsLabel: context.loc.syncIncomplete,
                    ),
                  const Gap(BullSpacing.sm),
                  Expanded(
                    child: BullText(
                      sending
                          ? context.loc.syncSendIncomplete
                          : status.networkPolicy?.pauseReason == null
                          ? context.loc.syncIncomplete
                          : status.message(context, DateTime.now().toUtc()),
                      style: context.bullText.bodySmall,
                    ),
                  ),
                ],
              ),
              if ((
                    sending,
                    status.networkPolicy?.pauseReason,
                    onContinueOnMobileData,
                  )
                  case (
                    false,
                    CbfNetworkPauseReason.mobileData,
                    final resume?,
                  )) ...[
                const Gap(BullSpacing.sm),
                BullButton.small(
                  label: context.loc.syncContinueMobileData,
                  onPressed: resume,
                  bgColor: context.bull.primary,
                  textColor: context.bull.onPrimary,
                ),
                if (onSettings case final open?) ...[
                  const Gap(BullSpacing.xs),
                  BullButton.small(
                    label: context.loc.syncSettingsAction,
                    onPressed: open,
                    bgColor: context.bull.surface,
                    textColor: context.bull.primary,
                    outlined: true,
                  ),
                ],
              ],
            ],
          ),
        )
      : const SizedBox.shrink();
}
