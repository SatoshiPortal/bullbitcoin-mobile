import 'dart:async';
import 'package:bb_mobile/core/wallet/domain/bitcoin_sync_operation_exception.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:transaction_sync/transaction_sync.dart';
import '../repositories/wallet_sync_status_repository.dart';
import '../wallet_sync_options_failure.dart';

class StartWalletSyncUsecase {
  final GetWalletUsecase _get;
  final SyncWalletUsecase _sync;
  final WalletSyncStatusRepository _status;
  final _active = <String>{};
  final _pendingPolicy = <String>{};

  StartWalletSyncUsecase({
    required this._get,
    required this._sync,
    required this._status,
  });

  /// The foreground operation outlives the screen; failures remain observable.
  void execute(String walletId, {bool policyChanged = false}) {
    if (_active.contains(walletId)) {
      if (policyChanged) {
        _pendingPolicy.add(walletId);
        _status.invalidate(walletId);
      }
      return;
    }
    _active.add(walletId);
    _status.invalidate(walletId);
    unawaited(_run(walletId));
  }

  Future<void> _run(String walletId) async {
    try {
      final wallet = await _get.execute(walletId);
      if (wallet == null) {
        _status.reportFailure(
          walletId,
          const WalletSyncOptionsStorageFailure(),
        );
        return;
      }
      await _sync.execute(wallet, discoverHistory: true);
    } on BitcoinSyncOperationException catch (error) {
      _status.reportFailure(walletId, switch (error.failure) {
        CbfNoPeersFailure() => const WalletSyncNoPeersFailure(),
        CbfTorUnavailableFailure() => const WalletSyncTorFailure(),
        WalletSyncDeferredFailure() ||
        CbfNodeDidNotStopFailure() => const WalletSyncPausedFailure(),
        _ => const WalletSyncUnexpectedFailure(),
      });
    } on Exception {
      _status.reportFailure(walletId, const WalletSyncUnexpectedFailure());
    } finally {
      _active.remove(walletId);
      if (_pendingPolicy.remove(walletId)) execute(walletId);
    }
  }
}
