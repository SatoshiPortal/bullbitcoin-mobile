import 'package:sync/sync.dart';

/// Invalidates this feature's read model without triggering network work.
final class WatchWalletRevisionsUsecase {
  final Stream<WalletRevisionState> _revisions;
  const WatchWalletRevisionsUsecase(this._revisions);

  Stream<String> execute({String? walletId}) => _revisions
      .where(
        (revision) => walletId == null || revision.stamp.key.id == walletId,
      )
      .map((revision) => revision.stamp.key.id);
}
