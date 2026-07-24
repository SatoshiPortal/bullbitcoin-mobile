import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';

/// The typed contract for synchronizing a single wallet's chain data,
/// independent of the backend that performs the sync (Electrum today; a
/// future compact-filter backend behind its own implementation).
///
/// Every method is keyed by `walletId` (the persisted wallet metadata id,
/// i.e. `Wallet.id`) rather than a full `Wallet` entity, since a long-running
/// backend session is owned per-wallet and can outlive any single entity
/// snapshot passed in by a caller.
abstract interface class WalletSyncRepository {
  /// Starts (or joins an already in-flight) sync for [walletId] and resolves
  /// once it settles. Implementations must not start a second concurrent
  /// sync for the same wallet — a call while one is already running joins
  /// that attempt instead.
  Future<Result<void, WalletSyncFailure>> startSync({required String walletId});

  /// Advisory progress for every wallet sync this repository drives.
  /// Filter by `WalletSyncProgress.walletId` for a single wallet.
  ///
  /// Never carries the terminal success/failure — that is reported only by
  /// the [Result] a [startSync] call resolves with.
  Stream<WalletSyncProgress> watchProgress();

  /// Requests cancellation of an in-flight sync for [walletId].
  ///
  /// Backends that cannot interrupt a sync already in progress (Electrum
  /// today) let the current attempt run to completion; callers must not
  /// assume immediate cancellation from this call alone — await the
  /// [startSync] result to know the actual outcome.
  Future<void> cancelSync({required String walletId});
}
