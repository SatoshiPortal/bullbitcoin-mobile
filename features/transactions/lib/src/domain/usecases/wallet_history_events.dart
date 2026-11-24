import 'package:sync/sync.dart';

/// Foreground sync events used to coalesce history reloads.
final class WalletHistoryEvents {
  final Stream<WalletRevisionState> Function({String? walletId}) watchRevisions;
  final Stream<bool> Function() watchSyncPassActivity;
  final Stream<void> Function() watchSyncFinished;
  final bool Function() isSyncPassActive;

  const WalletHistoryEvents({
    required this.watchRevisions,
    required this.watchSyncPassActivity,
    required this.watchSyncFinished,
    required this.isSyncPassActive,
  });

  factory WalletHistoryEvents.foreground({
    required Stream<WalletRevisionState> revisions,
    required Stream<SyncFinished> finished,
    required Stream<bool> Function() watchSyncPassActivity,
    required bool Function() isSyncPassActive,
  }) => WalletHistoryEvents(
    watchRevisions: ({walletId}) => revisions.where(
      (revision) => walletId == null || revision.stamp.key.id == walletId,
    ),
    watchSyncPassActivity: watchSyncPassActivity,
    watchSyncFinished: () => finished.map((_) {}),
    isSyncPassActive: isSyncPassActive,
  );
}
