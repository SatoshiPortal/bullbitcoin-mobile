import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/cbf_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_sync_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';

/// Adapts [CbfWalletDatasource] — the foreground compact block filter
/// (BIP157/158) backend — to the [WalletSyncRepository] contract.
///
/// This repository does not decide *whether* CBF is allowed to run for a
/// given wallet (developer gate, Tor interaction, or which backend a
/// wallet's metadata selects) — that policy lives in
/// `WalletSyncRoutingRepository`, which is what `WalletLocator` registers as
/// the app-wide `WalletSyncRepository`. This class is only reachable through
/// that router.
class CbfWalletSyncRepository implements WalletSyncRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final CbfWalletDatasource _cbfWalletDatasource;

  CbfWalletSyncRepository({
    required this._walletMetadataDatasource,
    required this._cbfWalletDatasource,
  });

  @override
  Future<Result<void, WalletSyncFailure>> startSync({
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      return const Err(WalletSyncWalletNotFoundFailure());
    }

    final result = await _cbfWalletDatasource.startSync(metadata: metadata);
    switch (result) {
      case Ok(value: final outcome):
        if (outcome == CbfSyncOutcome.completed) {
          // Never persisted for CbfSyncOutcome.cancelled — a deliberate
          // cancellation must not be recorded as a successful sync (it
          // would make CbfScanTypeResolver pick SyncScanType next run as
          // if a real scan had actually completed).
          // A CBF scan can run for a long time. Reload before persisting the
          // completion timestamp so a concurrent backend change or revealed
          // receive index is never overwritten with this attempt's snapshot.
          final latestMetadata = await _walletMetadataDatasource.fetch(
            walletId,
          );
          if (latestMetadata != null) {
            await _walletMetadataDatasource.store(
              latestMetadata.copyWith(syncedAt: DateTime.now().toUtc()),
            );
          }
        }
        return const Ok(null);
      case Err(failure: final failure):
        return Err(failure);
    }
  }

  @override
  Stream<WalletSyncProgress> watchProgress() =>
      _cbfWalletDatasource.watchProgress();

  @override
  Future<void> cancelSync({required String walletId}) =>
      _cbfWalletDatasource.cancelSync(walletId: walletId);
}
