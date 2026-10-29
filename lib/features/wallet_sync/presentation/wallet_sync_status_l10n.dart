import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart' show BuildContext;
import 'package:intl/intl.dart';
import 'package:transaction_sync/transaction_sync.dart';
import '../domain/wallet_sync_status.dart';
import '../domain/wallet_sync_options_failure.dart';
import 'wallet_sync_options_failure_l10n.dart';

String syncRelativeTime(BuildContext context, DateTime? at, DateTime now) {
  if (at == null) return context.loc.syncUnknownTime;
  final age = now.difference(at);
  if (age.inMinutes < 1) return context.loc.syncJustNow;
  if (age.inHours < 1) return context.loc.syncMinutesAgo(age.inMinutes);
  if (age.inDays < 1) return context.loc.syncHoursAgo(age.inHours);
  return context.loc.syncDaysAgo(age.inDays);
}

extension WalletSyncStatusL10n on WalletSyncStatus {
  String message(BuildContext context, DateTime now) {
    final reason = isPrivate ? networkPolicy?.pauseReason : null;
    if (reason == CbfNetworkPauseReason.offline) {
      return context.loc.syncPausedOffline;
    }
    if (reason == CbfNetworkPauseReason.mobileData) {
      return context.loc.syncPausedMobileData;
    }
    final error = failure;
    if (error is WalletSyncNoPeersFailure) {
      return context.loc.syncNoPeers(
        syncRelativeTime(context, lastSuccessfulSync, now),
      );
    }
    if (error != null) return error.toTranslated(context);
    return switch (progress?.phase) {
      BitcoinSyncPhase.findingPeers => switch (progress?.startedAt) {
        final started?
            when now.difference(started) >= const Duration(minutes: 2) =>
          context.loc.syncStillFindingPeers,
        _ => context.loc.syncFindingPeers,
      },
      BitcoinSyncPhase.checkingBlocks => context.loc.syncCheckingBlocks,
      BitcoinSyncPhase.downloadingTransactions =>
        context.loc.syncDownloadingTransactions,
      _ when incomplete => context.loc.syncFindingPeers,
      _ when lastSuccessfulSync != null => context.loc.syncUpToDate(
        progress?.targetHeight == null
            ? '—'
            : NumberFormat.decimalPattern(
                context.loc.localeName,
              ).format(progress?.targetHeight),
        syncRelativeTime(context, lastSuccessfulSync, now),
      ),
      _ => isPrivate ? context.loc.syncPaused : context.loc.syncServerOnly,
    };
  }
}
