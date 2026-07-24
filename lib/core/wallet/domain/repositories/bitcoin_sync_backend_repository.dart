import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';

/// The persisted [BitcoinSyncBackend] choice for a single Bitcoin wallet.
///
/// Bitcoin-only: every method fails with [WalletSyncNotBitcoinWalletFailure]
/// for a Liquid wallet id. This is a plain get/set of the wallet's stored
/// choice — it never starts, stops, or gates a sync itself (that stays
/// `WalletSyncRepository`'s job, reached through `StartWalletSyncUsecase`).
abstract interface class BitcoinSyncBackendRepository {
  /// The wallet's currently persisted backend.
  Future<Result<BitcoinSyncBackend, WalletSyncFailure>> get({
    required String walletId,
  });

  /// Persists [backend] as the wallet's chosen sync backend. Does not start
  /// or cancel any sync — callers that want compact block filters to
  /// actually run still call `StartWalletSyncUsecase` themselves.
  Future<Result<void, WalletSyncFailure>> set({
    required String walletId,
    required BitcoinSyncBackend backend,
  });
}
