import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_sync_repository.dart';

/// The single sync entry point every caller — foreground (`SyncCoordinator`)
/// and background (`lib/core/background_tasks/handler.dart`) alike — goes
/// through, split by [allowCompactBlockFilters]:
///
/// - `true` (the default, used by `SyncCoordinator` and every other
///   foreground caller): routes through [WalletSyncRepository] — Electrum
///   for every wallet today, or compact block filters for a Bitcoin wallet
///   that both persisted that choice (`BitcoinSyncBackend`) and passes
///   `WalletSyncRoutingRepository`'s developer/Tor gate. This is what makes
///   a wizard-created CBF wallet actually sync with CBF: the wizard only
///   *persists* the choice (see `CreateDefaultWalletsUsecase`), and this is
///   the first place it is ever acted on.
/// - `false` (background tasks only): bypasses the router entirely and
///   calls the legacy [WalletRepository.sync] directly, forcing Electrum
///   regardless of a wallet's persisted backend. Compact block filters is
///   V1-foreground-only — a background isolate must never start a CBF
///   session.
class SyncWalletUsecase {
  final WalletSyncRepository _walletSyncRepository;
  final WalletRepository _wallet;

  SyncWalletUsecase({
    required this._walletSyncRepository,
    required WalletRepository walletRepository,
  }) : _wallet = walletRepository;

  Future<void> execute(
    Wallet wallet, {
    bool allowCompactBlockFilters = true,
  }) async {
    if (!allowCompactBlockFilters) {
      try {
        await _wallet.sync(wallet);
      } catch (e) {
        throw SyncWalletException('$e');
      }
      return;
    }

    final result = await _walletSyncRepository.startSync(walletId: wallet.id);
    switch (result) {
      case Ok():
        return;
      case Err(:final failure):
        throw SyncWalletException(
          failure.logMessage ?? failure.runtimeType.toString(),
        );
    }
  }
}

class SyncWalletException extends BullException {
  SyncWalletException(super.message);
}
