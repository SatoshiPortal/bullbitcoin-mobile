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
}
